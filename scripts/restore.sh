#!/bin/bash

# Horizen Network Restore Script
# Restores databases and configurations from backups

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Restore Script ===${NC}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Configuration
BACKUP_DIR="${BACKUP_PATH:-./backups}"

# Function to display usage
usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo "Options:"
    echo "  -d, --date DATE       Restore from backup with specific date (format: YYYYMMDD_HHMMSS)"
    echo "  -l, --list            List available backups"
    echo "  -p, --postgres        Restore PostgreSQL only"
    echo "  -m, --mongodb         Restore MongoDB only"
    echo "  -c, --config          Restore configuration only"
    echo "  -D, --druid           Restore Druid segments only"
    echo "  -a, --all             Restore everything (default)"
    echo "  -f, --force           Skip confirmation prompts"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --list                                    # List available backups"
    echo "  $0 --date 20241215_120000                    # Restore specific backup"
    echo "  $0 --date 20241215_120000 --postgres         # Restore only PostgreSQL"
    echo "  $0 --date 20241215_120000 --force            # Restore without confirmation"
    exit 0
}

# Function to list backups
list_backups() {
    echo -e "\n${YELLOW}Available backups in ${BACKUP_DIR}:${NC}\n"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}Backup directory does not exist${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}PostgreSQL backups:${NC}"
    ls -lh "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | tail -10 || echo "  No PostgreSQL backups found"
    
    echo -e "\n${BLUE}MongoDB backups:${NC}"
    ls -lh "$BACKUP_DIR"/mongodb_*.tar.gz 2>/dev/null | tail -10 || echo "  No MongoDB backups found"
    
    echo -e "\n${BLUE}Druid segment backups:${NC}"
    ls -lh "$BACKUP_DIR"/druid_segments_*.tar.gz 2>/dev/null | tail -10 || echo "  No Druid backups found"
    
    echo -e "\n${BLUE}Configuration backups:${NC}"
    ls -lh "$BACKUP_DIR"/config_*.tar.gz 2>/dev/null | tail -10 || echo "  No configuration backups found"
    
    exit 0
}

# Function to verify backup exists
verify_backup() {
    local backup_file=$1
    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found: $backup_file${NC}"
        return 1
    fi
    return 0
}

# Function to restore PostgreSQL
restore_postgres() {
    local date=$1
    local backup_file="$BACKUP_DIR/postgres_${date}.sql.gz"
    
    echo -e "\n${YELLOW}Restoring PostgreSQL...${NC}"
    
    if ! verify_backup "$backup_file"; then
        return 1
    fi
    
    # Stop services that depend on PostgreSQL
    echo -e "${YELLOW}Stopping Druid services...${NC}"
    docker-compose stop druid-coordinator druid-broker druid-router druid-historical druid-middlemanager 2>/dev/null || true
    
    # Restore database
    echo -e "${YELLOW}Restoring database from $backup_file...${NC}"
    gunzip -c "$backup_file" | docker-compose exec -T postgres psql -U ${POSTGRES_USER} -d ${POSTGRES_DB}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PostgreSQL restored successfully${NC}"
        
        # Restart services
        echo -e "${YELLOW}Restarting Druid services...${NC}"
        docker-compose up -d druid-coordinator druid-broker druid-router druid-historical druid-middlemanager
        return 0
    else
        echo -e "${RED}✗ PostgreSQL restore failed${NC}"
        return 1
    fi
}

# Function to restore MongoDB
restore_mongodb() {
    local date=$1
    local backup_file="$BACKUP_DIR/mongodb_${date}.tar.gz"
    
    echo -e "\n${YELLOW}Restoring MongoDB...${NC}"
    
    if ! verify_backup "$backup_file"; then
        return 1
    fi
    
    # Extract backup
    local temp_dir="/tmp/mongodb_restore_$$"
    mkdir -p "$temp_dir"
    
    echo -e "${YELLOW}Extracting backup...${NC}"
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Copy to container
    echo -e "${YELLOW}Copying backup to MongoDB container...${NC}"
    docker cp "$temp_dir/." horizen-mongodb:/tmp/restore/
    
    # Restore database
    echo -e "${YELLOW}Restoring MongoDB database...${NC}"
    docker-compose exec -T mongodb mongorestore \
        --username=${MONGO_USER} \
        --password=${MONGO_PASSWORD} \
        --authenticationDatabase=admin \
        --db=${MONGO_DB} \
        --drop \
        /tmp/restore/
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ MongoDB restored successfully${NC}"
        # Cleanup
        rm -rf "$temp_dir"
        docker-compose exec -T mongodb rm -rf /tmp/restore
        return 0
    else
        echo -e "${RED}✗ MongoDB restore failed${NC}"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Function to restore Druid segments
restore_druid() {
    local date=$1
    local backup_file="$BACKUP_DIR/druid_segments_${date}.tar.gz"
    
    echo -e "\n${YELLOW}Restoring Druid segments...${NC}"
    
    if ! verify_backup "$backup_file"; then
        echo -e "${YELLOW}! No Druid segments backup found for this date${NC}"
        return 0
    fi
    
    # Stop Druid services
    echo -e "${YELLOW}Stopping Druid services...${NC}"
    docker-compose stop druid-coordinator druid-broker druid-router druid-historical druid-middlemanager
    
    # Get volume name
    local volume_name=$(docker volume ls --format '{{.Name}}' | grep druid-data | head -1)
    
    if [ -z "$volume_name" ]; then
        echo -e "${RED}Error: Could not find Druid data volume${NC}"
        return 1
    fi
    
    # Restore segments
    echo -e "${YELLOW}Restoring segments to volume $volume_name...${NC}"
    docker run --rm \
        -v "${volume_name}:/data" \
        -v "$BACKUP_DIR:/backup" \
        alpine sh -c "rm -rf /data/druid/segments/* && tar -xzf /backup/druid_segments_${date}.tar.gz -C /data"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Druid segments restored successfully${NC}"
        
        # Restart services
        echo -e "${YELLOW}Restarting Druid services...${NC}"
        docker-compose up -d druid-coordinator druid-broker druid-router druid-historical druid-middlemanager
        return 0
    else
        echo -e "${RED}✗ Druid segments restore failed${NC}"
        return 1
    fi
}

# Function to restore configuration
restore_config() {
    local date=$1
    local backup_file="$BACKUP_DIR/config_${date}.tar.gz"
    
    echo -e "\n${YELLOW}Restoring configuration files...${NC}"
    
    if ! verify_backup "$backup_file"; then
        return 1
    fi
    
    # Create backup of current config
    local config_backup="./config_before_restore_$(date +%Y%m%d_%H%M%S).tar.gz"
    echo -e "${YELLOW}Backing up current configuration to $config_backup...${NC}"
    tar -czf "$config_backup" nginx/ druid/ docker-compose*.yml 2>/dev/null || true
    
    # Restore configuration
    echo -e "${YELLOW}Restoring configuration from $backup_file...${NC}"
    tar -xzf "$backup_file" -C ./
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Configuration restored successfully${NC}"
        echo -e "${YELLOW}Note: Current configuration backed up to $config_backup${NC}"
        echo -e "${YELLOW}You may need to restart services for changes to take effect${NC}"
        return 0
    else
        echo -e "${RED}✗ Configuration restore failed${NC}"
        return 1
    fi
}

# Parse command line arguments
RESTORE_DATE=""
RESTORE_POSTGRES=false
RESTORE_MONGODB=false
RESTORE_DRUID=false
RESTORE_CONFIG=false
RESTORE_ALL=true
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--date)
            RESTORE_DATE="$2"
            shift 2
            ;;
        -l|--list)
            list_backups
            ;;
        -p|--postgres)
            RESTORE_POSTGRES=true
            RESTORE_ALL=false
            shift
            ;;
        -m|--mongodb)
            RESTORE_MONGODB=true
            RESTORE_ALL=false
            shift
            ;;
        -D|--druid)
            RESTORE_DRUID=true
            RESTORE_ALL=false
            shift
            ;;
        -c|--config)
            RESTORE_CONFIG=true
            RESTORE_ALL=false
            shift
            ;;
        -a|--all)
            RESTORE_ALL=true
            shift
            ;;
        -f|--force)
            FORCE=true
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

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Error: Backup directory $BACKUP_DIR does not exist${NC}"
    exit 1
fi

# If no date specified, find the latest backup
if [ -z "$RESTORE_DATE" ]; then
    echo -e "${YELLOW}No date specified, finding latest backup...${NC}"
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/postgres_*.sql.gz 2>/dev/null | head -1)
    if [ -z "$LATEST_BACKUP" ]; then
        echo -e "${RED}Error: No backups found in $BACKUP_DIR${NC}"
        echo -e "${YELLOW}Run '$0 --list' to see available backups${NC}"
        exit 1
    fi
    RESTORE_DATE=$(basename "$LATEST_BACKUP" .sql.gz | sed 's/postgres_//')
    echo -e "${GREEN}Latest backup found: $RESTORE_DATE${NC}"
fi

# Confirmation
if [ "$FORCE" = false ]; then
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}WARNING: This will restore data from backup!${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "Backup date: ${GREEN}$RESTORE_DATE${NC}"
    echo -e "Backup location: ${GREEN}$BACKUP_DIR${NC}"
    echo ""
    if [ "$RESTORE_ALL" = true ]; then
        echo -e "Will restore: ${GREEN}All components${NC}"
    else
        [ "$RESTORE_POSTGRES" = true ] && echo -e "Will restore: ${GREEN}PostgreSQL${NC}"
        [ "$RESTORE_MONGODB" = true ] && echo -e "Will restore: ${GREEN}MongoDB${NC}"
        [ "$RESTORE_DRUID" = true ] && echo -e "Will restore: ${GREEN}Druid segments${NC}"
        [ "$RESTORE_CONFIG" = true ] && echo -e "Will restore: ${GREEN}Configuration${NC}"
    fi
    echo ""
    echo -e "${RED}Current data will be overwritten!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        exit 0
    fi
fi

# Start restore process
echo -e "\n${GREEN}Starting restore process...${NC}"
echo -e "Timestamp: $(date)"

ERRORS=0

# Restore components
if [ "$RESTORE_ALL" = true ] || [ "$RESTORE_POSTGRES" = true ]; then
    if ! restore_postgres "$RESTORE_DATE"; then
        ((ERRORS++))
    fi
fi

if [ "$RESTORE_ALL" = true ] || [ "$RESTORE_MONGODB" = true ]; then
    if ! restore_mongodb "$RESTORE_DATE"; then
        ((ERRORS++))
    fi
fi

if [ "$RESTORE_ALL" = true ] || [ "$RESTORE_DRUID" = true ]; then
    if ! restore_druid "$RESTORE_DATE"; then
        ((ERRORS++))
    fi
fi

if [ "$RESTORE_ALL" = true ] || [ "$RESTORE_CONFIG" = true ]; then
    if ! restore_config "$RESTORE_DATE"; then
        ((ERRORS++))
    fi
fi

# Summary
echo -e "\n${GREEN}=== Restore Complete ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All components restored successfully!${NC}"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "1. Verify services are running: ${BLUE}docker-compose ps${NC}"
    echo -e "2. Run health check: ${BLUE}./scripts/health-check.sh${NC}"
    echo -e "3. Check application logs for any errors"
    exit 0
else
    echo -e "${RED}Restore completed with $ERRORS error(s)${NC}"
    echo -e "${YELLOW}Please check the error messages above and take corrective action${NC}"
    exit 1
fi
