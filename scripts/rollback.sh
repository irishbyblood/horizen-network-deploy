#!/bin/bash

# Horizen Network Rollback Script
# Rollback to previous deployment or restore from backup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Rollback Script ===${NC}"

# Configuration
BACKUP_DIR="${BACKUP_PATH:-./backups}"
STATE_FILE=".deployment_state"
LOG_DIR="./logs"
ROLLBACK_LOG="$LOG_DIR/rollback_$(date +%Y%m%d_%H%M%S).log"

# Create directories
mkdir -p "$LOG_DIR"

# Redirect output to log
exec > >(tee -a "$ROLLBACK_LOG")
exec 2>&1

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Parse command line arguments
ROLLBACK_TYPE="auto"
BACKUP_FILE=""
PRESERVE_LOGS=true
SKIP_CONFIRMATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --backup)
            ROLLBACK_TYPE="backup"
            BACKUP_FILE="$2"
            shift 2
            ;;
        --docker)
            ROLLBACK_TYPE="docker"
            shift
            ;;
        --auto)
            ROLLBACK_TYPE="auto"
            shift
            ;;
        --yes|-y)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --no-preserve-logs)
            PRESERVE_LOGS=false
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --backup FILE    Rollback from specific backup file
  --docker         Rollback Docker images to previous versions
  --auto           Auto-detect rollback method (default)
  --yes, -y        Skip confirmation prompts
  --no-preserve-logs  Don't preserve current logs
  --help, -h       Show this help message

Examples:
  $0 --auto                                    # Auto-detect and rollback
  $0 --backup backups/postgres_20240101.sql.gz # Restore from specific backup
  $0 --docker --yes                            # Rollback Docker images without confirmation
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "Rollback started at: $(date)"
echo -e "Rollback type: $ROLLBACK_TYPE"

# ======================
# Helper Functions
# ======================

# Function to save current state
save_current_state() {
    echo -e "\n${YELLOW}Saving current state...${NC}"
    
    cat > "$STATE_FILE" <<EOF
TIMESTAMP=$(date +%s)
DATE=$(date +%Y%m%d_%H%M%S)
CONTAINERS=$(docker-compose ps -q | tr '\n' ',')
IMAGES=$(docker-compose images -q | tr '\n' ',')
GIT_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
EOF
    
    echo -e "${GREEN}✓ Current state saved to $STATE_FILE${NC}"
}

# Function to check if rollback is needed
check_deployment_health() {
    echo -e "\n${YELLOW}Checking deployment health...${NC}"
    
    if ./scripts/health-check.sh > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Deployment is healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Deployment has issues${NC}"
        return 1
    fi
}

# Function to find latest backup
find_latest_backup() {
    local backup_type=$1
    local latest_backup=$(ls -t "$BACKUP_DIR"/${backup_type}_*.{sql.gz,tar.gz,gpg} 2>/dev/null | head -1)
    echo "$latest_backup"
}

# Function to stop services
stop_services() {
    echo -e "\n${YELLOW}Stopping services...${NC}"
    if docker-compose down; then
        echo -e "${GREEN}✓ Services stopped${NC}"
    else
        echo -e "${RED}✗ Failed to stop services${NC}"
        return 1
    fi
}

# Function to preserve logs
preserve_logs() {
    if [ "$PRESERVE_LOGS" = true ]; then
        echo -e "\n${YELLOW}Preserving logs...${NC}"
        local log_backup_dir="$LOG_DIR/rollback_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$log_backup_dir"
        
        # Save container logs
        for container in $(docker-compose ps -q 2>/dev/null); do
            container_name=$(docker inspect --format='{{.Name}}' $container | sed 's/\///')
            docker logs $container > "$log_backup_dir/${container_name}.log" 2>&1 || true
        done
        
        echo -e "${GREEN}✓ Logs preserved in $log_backup_dir${NC}"
    fi
}

# ======================
# Rollback Methods
# ======================

# Method 1: Rollback Docker Images
rollback_docker_images() {
    echo -e "\n${YELLOW}=== Rolling back Docker images ===${NC}"
    
    # Stop current containers
    stop_services
    
    # Pull previous image versions (if specified in docker-compose)
    echo "Pulling previous image versions..."
    if docker-compose pull; then
        echo -e "${GREEN}✓ Images pulled${NC}"
    else
        echo -e "${RED}✗ Failed to pull images${NC}"
        return 1
    fi
    
    # Start services with previous images
    echo "Starting services with previous images..."
    if docker-compose up -d; then
        echo -e "${GREEN}✓ Services started${NC}"
        
        # Wait for services to be ready
        echo "Waiting for services to be ready (30s)..."
        sleep 30
        
        # Check health
        if check_deployment_health; then
            echo -e "${GREEN}✓ Rollback successful${NC}"
            return 0
        else
            echo -e "${RED}✗ Services started but health check failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start services${NC}"
        return 1
    fi
}

# Method 2: Restore from Backup
restore_from_backup() {
    local backup_file=$1
    
    echo -e "\n${YELLOW}=== Restoring from backup ===${NC}"
    
    if [ -z "$backup_file" ]; then
        echo "No backup file specified, finding latest..."
        POSTGRES_BACKUP=$(find_latest_backup "postgres")
        MONGO_BACKUP=$(find_latest_backup "mongodb")
        
        if [ -z "$POSTGRES_BACKUP" ] && [ -z "$MONGO_BACKUP" ]; then
            echo -e "${RED}✗ No backups found in $BACKUP_DIR${NC}"
            return 1
        fi
    else
        if [ ! -f "$backup_file" ]; then
            echo -e "${RED}✗ Backup file not found: $backup_file${NC}"
            return 1
        fi
    fi
    
    # Ensure services are running
    echo "Ensuring services are running..."
    docker-compose up -d postgres mongodb redis
    sleep 10
    
    # Restore PostgreSQL
    if [ -n "$POSTGRES_BACKUP" ] && [ -f "$POSTGRES_BACKUP" ]; then
        echo -e "\n${YELLOW}Restoring PostgreSQL from $POSTGRES_BACKUP...${NC}"
        
        # Decompress if needed
        if [[ "$POSTGRES_BACKUP" == *.gpg ]]; then
            echo "Decrypting backup..."
            gpg --decrypt --batch --yes --passphrase="${BACKUP_ENCRYPTION_KEY:-changeme}" \
                "$POSTGRES_BACKUP" | gunzip | \
                docker-compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
        elif [[ "$POSTGRES_BACKUP" == *.gz ]]; then
            gunzip -c "$POSTGRES_BACKUP" | \
                docker-compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
        else
            docker-compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} < "$POSTGRES_BACKUP"
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ PostgreSQL restored${NC}"
        else
            echo -e "${RED}✗ PostgreSQL restoration failed${NC}"
            return 1
        fi
    fi
    
    # Restore MongoDB
    if [ -n "$MONGO_BACKUP" ] && [ -f "$MONGO_BACKUP" ]; then
        echo -e "\n${YELLOW}Restoring MongoDB from $MONGO_BACKUP...${NC}"
        
        local temp_dir="/tmp/mongo_restore_$$"
        mkdir -p "$temp_dir"
        
        # Extract backup
        if [[ "$MONGO_BACKUP" == *.gpg ]]; then
            gpg --decrypt --batch --yes --passphrase="${BACKUP_ENCRYPTION_KEY:-changeme}" \
                "$MONGO_BACKUP" | tar -xzf - -C "$temp_dir"
        else
            tar -xzf "$MONGO_BACKUP" -C "$temp_dir"
        fi
        
        # Copy to container and restore
        docker cp "$temp_dir/." horizen-mongodb:/tmp/restore/
        docker-compose exec -T mongodb mongorestore \
            --username=${MONGO_USER} \
            --password=${MONGO_PASSWORD} \
            --authenticationDatabase=admin \
            --db=${MONGO_DB} \
            --drop \
            /tmp/restore/
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ MongoDB restored${NC}"
            docker-compose exec -T mongodb rm -rf /tmp/restore
        else
            echo -e "${RED}✗ MongoDB restoration failed${NC}"
            return 1
        fi
        
        rm -rf "$temp_dir"
    fi
    
    # Restart all services
    echo -e "\n${YELLOW}Restarting all services...${NC}"
    docker-compose restart
    sleep 30
    
    # Check health
    if check_deployment_health; then
        echo -e "${GREEN}✓ Restoration successful${NC}"
        return 0
    else
        echo -e "${RED}✗ Services restored but health check failed${NC}"
        return 1
    fi
}

# Method 3: Git Rollback
rollback_git() {
    echo -e "\n${YELLOW}=== Rolling back Git repository ===${NC}"
    
    if [ ! -d .git ]; then
        echo -e "${YELLOW}⚠ Not a git repository, skipping git rollback${NC}"
        return 0
    fi
    
    # Get previous commit
    local prev_commit=$(git log --oneline -2 | tail -1 | awk '{print $1}')
    
    if [ -z "$prev_commit" ]; then
        echo -e "${RED}✗ Cannot find previous commit${NC}"
        return 1
    fi
    
    echo "Previous commit: $prev_commit"
    
    if [ "$SKIP_CONFIRMATION" = false ]; then
        read -p "Rollback to this commit? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Git rollback cancelled"
            return 1
        fi
    fi
    
    git checkout "$prev_commit"
    echo -e "${GREEN}✓ Git rolled back to $prev_commit${NC}"
}

# ======================
# Main Rollback Logic
# ======================

echo -e "\n${YELLOW}=== Starting Rollback Process ===${NC}"

# Confirmation
if [ "$SKIP_CONFIRMATION" = false ]; then
    echo -e "${YELLOW}This will rollback the deployment.${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rollback cancelled"
        exit 0
    fi
fi

# Save current state
save_current_state

# Preserve current logs
preserve_logs

# Send notification
if [ -f "./scripts/notify.sh" ]; then
    ./scripts/notify.sh "deployment_rollback_started" "Rollback initiated for $(hostname)" || true
fi

# Execute rollback based on type
ROLLBACK_SUCCESS=false

case "$ROLLBACK_TYPE" in
    auto)
        echo "Auto-detecting rollback method..."
        
        # Try to detect issues and rollback accordingly
        if ! check_deployment_health; then
            echo "Health check failed, attempting backup restoration..."
            if restore_from_backup ""; then
                ROLLBACK_SUCCESS=true
            else
                echo "Backup restoration failed, attempting Docker rollback..."
                if rollback_docker_images; then
                    ROLLBACK_SUCCESS=true
                fi
            fi
        else
            echo "Deployment appears healthy, no rollback needed"
            ROLLBACK_SUCCESS=true
        fi
        ;;
    
    backup)
        if restore_from_backup "$BACKUP_FILE"; then
            ROLLBACK_SUCCESS=true
        fi
        ;;
    
    docker)
        if rollback_docker_images; then
            ROLLBACK_SUCCESS=true
        fi
        ;;
esac

# Final health check
echo -e "\n${YELLOW}=== Running Final Health Check ===${NC}"
sleep 5

if check_deployment_health; then
    echo -e "\n${GREEN}=== Rollback Complete ===${NC}"
    echo -e "${GREEN}✓ All services are healthy${NC}"
    ROLLBACK_SUCCESS=true
else
    echo -e "\n${RED}=== Rollback Incomplete ===${NC}"
    echo -e "${RED}✗ Some services are still unhealthy${NC}"
    echo -e "${YELLOW}Manual intervention may be required${NC}"
    ROLLBACK_SUCCESS=false
fi

echo -e "\nRollback finished at: $(date)"
echo -e "Log file: $ROLLBACK_LOG"

# Send notification
if [ -f "./scripts/notify.sh" ]; then
    if [ "$ROLLBACK_SUCCESS" = true ]; then
        ./scripts/notify.sh "deployment_rollback_success" "Rollback completed successfully" || true
    else
        ./scripts/notify.sh "deployment_rollback_failed" "Rollback completed with issues" || true
    fi
fi

# Exit with appropriate code
if [ "$ROLLBACK_SUCCESS" = true ]; then
    exit 0
else
    exit 1
fi
