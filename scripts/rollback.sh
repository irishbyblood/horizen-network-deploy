#!/bin/bash

# Horizen Network Rollback Script
# Rolls back deployment to a previous version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Horizen Network Rollback Script ===${NC}"

# Check if running as root for certain operations
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Warning: Running as root${NC}"
fi

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tag TAG        Docker image tag to rollback to"
    echo "  -c, --commit COMMIT  Git commit hash to rollback to"
    echo "  -b, --branch BRANCH  Git branch to rollback to"
    echo "  -d, --db-backup FILE Database backup file to restore"
    echo "  -s, --skip-db        Skip database rollback"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --commit abc123"
    echo "  $0 --tag v1.0.0"
    echo "  $0 --commit abc123 --skip-db"
    exit 1
}

# Default values
TARGET_COMMIT=""
TARGET_TAG=""
TARGET_BRANCH=""
DB_BACKUP=""
SKIP_DB=false
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ROLLBACK_BACKUP_DIR="./rollback_backup_${TIMESTAMP}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tag)
            TARGET_TAG="$2"
            shift 2
            ;;
        -c|--commit)
            TARGET_COMMIT="$2"
            shift 2
            ;;
        -b|--branch)
            TARGET_BRANCH="$2"
            shift 2
            ;;
        -d|--db-backup)
            DB_BACKUP="$2"
            shift 2
            ;;
        -s|--skip-db)
            SKIP_DB=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate arguments
if [ -z "$TARGET_COMMIT" ] && [ -z "$TARGET_TAG" ] && [ -z "$TARGET_BRANCH" ]; then
    echo -e "${RED}Error: Must specify --commit, --tag, or --branch${NC}"
    usage
fi

# Function to backup current state
backup_current_state() {
    echo -e "\n${YELLOW}Creating backup of current state...${NC}"
    
    mkdir -p "$ROLLBACK_BACKUP_DIR"
    
    # Backup current Git commit
    git rev-parse HEAD > "$ROLLBACK_BACKUP_DIR/commit.txt"
    echo -e "${GREEN}✓ Saved current commit${NC}"
    
    # Backup current environment file
    if [ -f .env ]; then
        cp .env "$ROLLBACK_BACKUP_DIR/.env.backup"
        echo -e "${GREEN}✓ Backed up .env file${NC}"
    fi
    
    # Backup current configuration files
    if [ -d nginx/conf.d ]; then
        cp -r nginx/conf.d "$ROLLBACK_BACKUP_DIR/nginx_conf.d"
        echo -e "${GREEN}✓ Backed up Nginx configuration${NC}"
    fi
    
    if [ -d druid/config ]; then
        cp -r druid/config "$ROLLBACK_BACKUP_DIR/druid_config"
        echo -e "${GREEN}✓ Backed up Druid configuration${NC}"
    fi
    
    # Backup databases if not skipping
    if [ "$SKIP_DB" = false ]; then
        echo -e "${YELLOW}Backing up databases...${NC}"
        
        # PostgreSQL backup
        if docker ps | grep -q horizen-postgres; then
            docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER:-druid} ${POSTGRES_DB:-druid_metadata} > "$ROLLBACK_BACKUP_DIR/postgres_backup.sql" 2>/dev/null || echo -e "${YELLOW}! PostgreSQL backup failed${NC}"
            if [ -f "$ROLLBACK_BACKUP_DIR/postgres_backup.sql" ]; then
                echo -e "${GREEN}✓ Backed up PostgreSQL database${NC}"
            fi
        fi
        
        # MongoDB backup
        if docker ps | grep -q horizen-mongodb; then
            docker-compose exec -T mongodb mongodump --quiet --out=/tmp/rollback_backup 2>/dev/null || echo -e "${YELLOW}! MongoDB backup failed${NC}"
            docker cp horizen-mongodb:/tmp/rollback_backup "$ROLLBACK_BACKUP_DIR/mongodb_backup" 2>/dev/null || echo -e "${YELLOW}! MongoDB backup copy failed${NC}"
            if [ -d "$ROLLBACK_BACKUP_DIR/mongodb_backup" ]; then
                echo -e "${GREEN}✓ Backed up MongoDB database${NC}"
            fi
        fi
    fi
    
    echo -e "${GREEN}Current state backed up to: $ROLLBACK_BACKUP_DIR${NC}"
}

# Function to perform Git rollback
perform_git_rollback() {
    echo -e "\n${YELLOW}Performing Git rollback...${NC}"
    
    # Stash any uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}Stashing uncommitted changes...${NC}"
        git stash save "Rollback stash ${TIMESTAMP}"
    fi
    
    # Perform rollback
    if [ -n "$TARGET_COMMIT" ]; then
        echo -e "${YELLOW}Rolling back to commit: $TARGET_COMMIT${NC}"
        git checkout "$TARGET_COMMIT" || {
            echo -e "${RED}Failed to checkout commit${NC}"
            exit 1
        }
    elif [ -n "$TARGET_TAG" ]; then
        echo -e "${YELLOW}Rolling back to tag: $TARGET_TAG${NC}"
        git checkout "tags/$TARGET_TAG" || {
            echo -e "${RED}Failed to checkout tag${NC}"
            exit 1
        }
    elif [ -n "$TARGET_BRANCH" ]; then
        echo -e "${YELLOW}Rolling back to branch: $TARGET_BRANCH${NC}"
        git checkout "$TARGET_BRANCH" || {
            echo -e "${RED}Failed to checkout branch${NC}"
            exit 1
        }
        git pull origin "$TARGET_BRANCH" || {
            echo -e "${RED}Failed to pull branch${NC}"
            exit 1
        }
    fi
    
    echo -e "${GREEN}✓ Git rollback completed${NC}"
}

# Function to rollback Docker images
perform_docker_rollback() {
    echo -e "\n${YELLOW}Rolling back Docker containers...${NC}"
    
    # Stop current containers
    echo -e "${YELLOW}Stopping current containers...${NC}"
    docker-compose down || {
        echo -e "${RED}Failed to stop containers${NC}"
        exit 1
    }
    
    # Pull images if tag specified
    if [ -n "$TARGET_TAG" ]; then
        echo -e "${YELLOW}Pulling images for tag: $TARGET_TAG${NC}"
        # Note: This assumes images are tagged in Docker registry
        docker-compose pull || echo -e "${YELLOW}! Could not pull images, using local${NC}"
    fi
    
    # Start containers
    echo -e "${YELLOW}Starting containers with rolled back configuration...${NC}"
    docker-compose up -d || {
        echo -e "${RED}Failed to start containers${NC}"
        exit 1
    }
    
    echo -e "${GREEN}✓ Docker containers rolled back${NC}"
}

# Function to rollback databases
perform_database_rollback() {
    if [ "$SKIP_DB" = true ]; then
        echo -e "\n${YELLOW}Skipping database rollback${NC}"
        return
    fi
    
    echo -e "\n${YELLOW}Rolling back databases...${NC}"
    
    if [ -z "$DB_BACKUP" ]; then
        echo -e "${YELLOW}No database backup specified, using current backup if available${NC}"
        DB_BACKUP="$ROLLBACK_BACKUP_DIR"
    fi
    
    # Wait for databases to be ready
    echo -e "${YELLOW}Waiting for databases to be ready...${NC}"
    sleep 10
    
    # Restore PostgreSQL
    if [ -f "${DB_BACKUP}/postgres_backup.sql" ] || [ -f "${DB_BACKUP}" ]; then
        echo -e "${YELLOW}Restoring PostgreSQL database...${NC}"
        
        POSTGRES_FILE="${DB_BACKUP}/postgres_backup.sql"
        if [ -f "${DB_BACKUP}" ]; then
            POSTGRES_FILE="${DB_BACKUP}"
        fi
        
        docker-compose exec -T postgres psql -U ${POSTGRES_USER:-druid} -d ${POSTGRES_DB:-druid_metadata} < "$POSTGRES_FILE" 2>/dev/null && {
            echo -e "${GREEN}✓ PostgreSQL database restored${NC}"
        } || {
            echo -e "${RED}✗ PostgreSQL restore failed${NC}"
        }
    else
        echo -e "${YELLOW}! No PostgreSQL backup found${NC}"
    fi
    
    # Restore MongoDB
    if [ -d "${DB_BACKUP}/mongodb_backup" ]; then
        echo -e "${YELLOW}Restoring MongoDB database...${NC}"
        
        docker cp "${DB_BACKUP}/mongodb_backup" horizen-mongodb:/tmp/ 2>/dev/null && {
            docker-compose exec -T mongodb mongorestore --quiet /tmp/mongodb_backup 2>/dev/null && {
                echo -e "${GREEN}✓ MongoDB database restored${NC}"
            } || {
                echo -e "${RED}✗ MongoDB restore failed${NC}"
            }
        } || {
            echo -e "${RED}✗ MongoDB backup copy failed${NC}"
        }
    else
        echo -e "${YELLOW}! No MongoDB backup found${NC}"
    fi
}

# Function to verify rollback
verify_rollback() {
    echo -e "\n${YELLOW}Verifying rollback...${NC}"
    
    # Wait for services to start
    sleep 15
    
    # Check container status
    if docker-compose ps | grep -q "Up"; then
        echo -e "${GREEN}✓ Containers are running${NC}"
    else
        echo -e "${RED}✗ Some containers are not running${NC}"
        docker-compose ps
    fi
    
    # Check health
    if [ -x "./scripts/health-check.sh" ]; then
        echo -e "${YELLOW}Running health check...${NC}"
        ./scripts/health-check.sh || echo -e "${YELLOW}! Health check reported issues${NC}"
    fi
    
    # Display current version
    echo -e "\n${BLUE}Current version:${NC}"
    git log -1 --oneline
}

# Function to create rollback record
create_rollback_record() {
    echo -e "\n${YELLOW}Creating rollback record...${NC}"
    
    ROLLBACK_LOG="./rollback_history.log"
    
    echo "====================" >> "$ROLLBACK_LOG"
    echo "Rollback Date: $(date)" >> "$ROLLBACK_LOG"
    echo "From Commit: $(cat $ROLLBACK_BACKUP_DIR/commit.txt 2>/dev/null || echo 'unknown')" >> "$ROLLBACK_LOG"
    echo "To Commit: $(git rev-parse HEAD)" >> "$ROLLBACK_LOG"
    if [ -n "$TARGET_TAG" ]; then
        echo "Target Tag: $TARGET_TAG" >> "$ROLLBACK_LOG"
    fi
    if [ -n "$TARGET_BRANCH" ]; then
        echo "Target Branch: $TARGET_BRANCH" >> "$ROLLBACK_LOG"
    fi
    echo "Database Rolled Back: $([ "$SKIP_DB" = false ] && echo 'Yes' || echo 'No')" >> "$ROLLBACK_LOG"
    echo "Backup Location: $ROLLBACK_BACKUP_DIR" >> "$ROLLBACK_LOG"
    echo "====================" >> "$ROLLBACK_LOG"
    
    echo -e "${GREEN}✓ Rollback record created${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}Starting rollback process...${NC}"
    echo -e "${YELLOW}This will rollback the deployment to a previous version.${NC}"
    echo -e "${RED}Press Ctrl+C within 10 seconds to cancel...${NC}"
    sleep 10
    
    # Step 1: Backup current state
    backup_current_state
    
    # Step 2: Git rollback
    perform_git_rollback
    
    # Step 3: Docker rollback
    perform_docker_rollback
    
    # Step 4: Database rollback
    perform_database_rollback
    
    # Step 5: Verify rollback
    verify_rollback
    
    # Step 6: Create rollback record
    create_rollback_record
    
    echo -e "\n${GREEN}=== Rollback completed successfully! ===${NC}"
    echo -e "${YELLOW}Backup of previous state: $ROLLBACK_BACKUP_DIR${NC}"
    echo -e "${YELLOW}To restore the previous state, use: $0 --commit \$(cat $ROLLBACK_BACKUP_DIR/commit.txt)${NC}"
}

# Run main function
main
