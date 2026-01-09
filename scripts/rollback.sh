#!/bin/bash

# Horizen Network Rollback Script
# Rolls back to a previous deployment state

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Rollback Script ===${NC}\n"

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --backup DATE     Restore from specific backup (format: YYYYMMDD_HHMMSS)"
    echo "  -c, --commit HASH     Rollback to specific git commit"
    echo "  -t, --tag TAG         Rollback to specific git tag"
    echo "  -f, --force           Skip confirmation prompts"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --backup 20241215_120000"
    echo "  $0 --commit abc123"
    echo "  $0 --tag v1.0.0"
    exit 0
}

# Parse arguments
BACKUP_DATE=""
GIT_COMMIT=""
GIT_TAG=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--backup)
            BACKUP_DATE="$2"
            shift 2
            ;;
        -c|--commit)
            GIT_COMMIT="$2"
            shift 2
            ;;
        -t|--tag)
            GIT_TAG="$2"
            shift 2
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

# Confirmation unless forced
if [ "$FORCE" = false ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}WARNING: Rollback Operation${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    if [ -n "$BACKUP_DATE" ]; then
        echo -e "This will restore backup from: ${GREEN}$BACKUP_DATE${NC}"
    elif [ -n "$GIT_COMMIT" ]; then
        echo -e "This will rollback code to commit: ${GREEN}$GIT_COMMIT${NC}"
    elif [ -n "$GIT_TAG" ]; then
        echo -e "This will rollback code to tag: ${GREEN}$GIT_TAG${NC}"
    else
        echo -e "${RED}Error: No rollback target specified${NC}"
        usage
    fi
    
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        echo -e "${YELLOW}Rollback cancelled${NC}"
        exit 0
    fi
fi

echo -e "\n${YELLOW}Starting rollback process...${NC}"

# Create pre-rollback backup
echo -e "\n${YELLOW}Creating pre-rollback backup...${NC}"
if ./scripts/backup.sh; then
    echo -e "${GREEN}✓ Pre-rollback backup created${NC}"
else
    echo -e "${RED}✗ Pre-rollback backup failed${NC}"
    exit 1
fi

# Stop services
echo -e "\n${YELLOW}Stopping services...${NC}"
docker-compose down
echo -e "${GREEN}✓ Services stopped${NC}"

# Rollback code if specified
if [ -n "$GIT_COMMIT" ] || [ -n "$GIT_TAG" ]; then
    echo -e "\n${YELLOW}Rolling back code...${NC}"
    
    # Stash any local changes
    git stash
    
    if [ -n "$GIT_COMMIT" ]; then
        git checkout "$GIT_COMMIT"
    elif [ -n "$GIT_TAG" ]; then
        git checkout "tags/$GIT_TAG"
    fi
    
    echo -e "${GREEN}✓ Code rolled back${NC}"
fi

# Restore backup if specified
if [ -n "$BACKUP_DATE" ]; then
    echo -e "\n${YELLOW}Restoring backup...${NC}"
    
    if ./scripts/restore.sh --date "$BACKUP_DATE" --force; then
        echo -e "${GREEN}✓ Backup restored${NC}"
    else
        echo -e "${RED}✗ Backup restoration failed${NC}"
        exit 1
    fi
fi

# Restart services
echo -e "\n${YELLOW}Restarting services...${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
echo -e "${GREEN}✓ Services restarted${NC}"

# Wait for services to start
echo -e "\n${YELLOW}Waiting for services to be ready...${NC}"
sleep 30

# Health check
echo -e "\n${YELLOW}Running health check...${NC}"
if ./scripts/health-check.sh; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo -e "${YELLOW}Services may need more time to start or there may be issues${NC}"
fi

echo -e "\n${GREEN}=== Rollback Complete ===${NC}"
echo -e "${YELLOW}Please verify the system is functioning correctly${NC}"
echo -e "${YELLOW}If issues persist, you may need to rollback further or restore from a different backup${NC}"
