#!/bin/bash

# Horizen Network Backup Script
# Creates backups of all databases and configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Backup Script ===${NC}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Configuration
BACKUP_DIR="${BACKUP_PATH:-./backups}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo -e "\n${YELLOW}Starting backup process...${NC}"
echo -e "Backup directory: $BACKUP_DIR"
echo -e "Timestamp: $DATE"

# Backup PostgreSQL (Druid metadata)
echo -e "\n${YELLOW}Backing up PostgreSQL...${NC}"
POSTGRES_BACKUP="$BACKUP_DIR/postgres_${DATE}.sql"
docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > "$POSTGRES_BACKUP"

if [ -f "$POSTGRES_BACKUP" ]; then
    gzip "$POSTGRES_BACKUP"
    echo -e "${GREEN}✓ PostgreSQL backup created: ${POSTGRES_BACKUP}.gz${NC}"
else
    echo -e "${RED}✗ PostgreSQL backup failed${NC}"
fi

# Backup MongoDB
echo -e "\n${YELLOW}Backing up MongoDB...${NC}"
MONGO_BACKUP="$BACKUP_DIR/mongodb_${DATE}"
mkdir -p "$MONGO_BACKUP"

docker-compose exec -T mongodb mongodump \
    --username=${MONGO_USER} \
    --password=${MONGO_PASSWORD} \
    --authenticationDatabase=admin \
    --db=${MONGO_DB} \
    --out=/tmp/backup

docker cp horizen-mongodb:/tmp/backup/. "$MONGO_BACKUP/"

if [ -d "$MONGO_BACKUP" ]; then
    tar -czf "${MONGO_BACKUP}.tar.gz" -C "$BACKUP_DIR" "mongodb_${DATE}"
    rm -rf "$MONGO_BACKUP"
    echo -e "${GREEN}✓ MongoDB backup created: ${MONGO_BACKUP}.tar.gz${NC}"
else
    echo -e "${RED}✗ MongoDB backup failed${NC}"
fi

# Backup Druid deep storage
echo -e "\n${YELLOW}Backing up Druid segments...${NC}"
DRUID_BACKUP="$BACKUP_DIR/druid_segments_${DATE}.tar.gz"

if docker-compose exec -T druid-coordinator test -d /opt/druid/var/druid/segments; then
    docker run --rm \
        -v horizen-network-deploy_druid-data:/data \
        -v "$BACKUP_DIR:/backup" \
        alpine tar -czf "/backup/druid_segments_${DATE}.tar.gz" -C /data druid/segments
    echo -e "${GREEN}✓ Druid segments backup created: $DRUID_BACKUP${NC}"
else
    echo -e "${YELLOW}! No Druid segments found to backup${NC}"
fi

# Backup configuration files
echo -e "\n${YELLOW}Backing up configuration files...${NC}"
CONFIG_BACKUP="$BACKUP_DIR/config_${DATE}.tar.gz"

tar -czf "$CONFIG_BACKUP" \
    --exclude='*.log' \
    --exclude='volumes' \
    --exclude='backups' \
    --exclude='.git' \
    nginx/ druid/ .env.example docker-compose*.yml 2>/dev/null || true

if [ -f "$CONFIG_BACKUP" ]; then
    echo -e "${GREEN}✓ Configuration backup created: $CONFIG_BACKUP${NC}"
else
    echo -e "${RED}✗ Configuration backup failed${NC}"
fi

# Clean old backups
echo -e "\n${YELLOW}Cleaning old backups (older than ${RETENTION_DAYS} days)...${NC}"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete 2>/dev/null || true
echo -e "${GREEN}✓ Old backups cleaned${NC}"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo -e "\n${GREEN}=== Backup Complete ===${NC}"
echo -e "Total backup size: $BACKUP_SIZE"
echo -e "Backups location: $BACKUP_DIR"

# List recent backups
echo -e "\n${YELLOW}Recent backups:${NC}"
ls -lh "$BACKUP_DIR" | tail -n 10
