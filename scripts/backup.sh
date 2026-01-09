#!/bin/bash

# Horizen Network Backup Script
# Creates backups of all databases and configurations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error tracking
BACKUP_ERRORS=0
BACKUP_WARNINGS=0

# Logging function
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Error handler
error_exit() {
    log "${RED}Error: $1${NC}"
    ((BACKUP_ERRORS++))
}

# Warning handler
warning() {
    log "${YELLOW}Warning: $1${NC}"
    ((BACKUP_WARNINGS++))
}

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
LOG_FILE="$BACKUP_DIR/backup_${DATE}.log"

# Create backup directory
if ! mkdir -p "$BACKUP_DIR"; then
    echo -e "${RED}Error: Cannot create backup directory $BACKUP_DIR${NC}"
    exit 1
fi

# Initialize log file
touch "$LOG_FILE" 2>/dev/null || {
    echo -e "${RED}Error: Cannot create log file${NC}"
    exit 1
}

log "\n${YELLOW}Starting backup process...${NC}"
log "Backup directory: $BACKUP_DIR"
log "Timestamp: $DATE"
log "Log file: $LOG_FILE"

# Verify Docker Compose is running
if ! docker-compose ps | grep -q "Up"; then
    error_exit "No Docker containers are running. Cannot perform backup."
    exit 1
fi

# Backup PostgreSQL (Druid metadata)
log "\n${YELLOW}Backing up PostgreSQL...${NC}"
POSTGRES_BACKUP="$BACKUP_DIR/postgres_${DATE}.sql"

if docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > "$POSTGRES_BACKUP" 2>>"$LOG_FILE"; then
    if [ -f "$POSTGRES_BACKUP" ] && [ -s "$POSTGRES_BACKUP" ]; then
        if gzip "$POSTGRES_BACKUP" 2>>"$LOG_FILE"; then
            POSTGRES_SIZE=$(du -h "${POSTGRES_BACKUP}.gz" | cut -f1)
            log "${GREEN}✓ PostgreSQL backup created: ${POSTGRES_BACKUP}.gz (${POSTGRES_SIZE})${NC}"
        else
            error_exit "Failed to compress PostgreSQL backup"
        fi
    else
        error_exit "PostgreSQL backup file is empty or not created"
    fi
else
    error_exit "PostgreSQL backup failed"
fi

# Backup MongoDB
log "\n${YELLOW}Backing up MongoDB...${NC}"
MONGO_BACKUP="$BACKUP_DIR/mongodb_${DATE}"

if mkdir -p "$MONGO_BACKUP" 2>>"$LOG_FILE"; then
    if docker-compose exec -T mongodb mongodump \
        --username=${MONGO_USER} \
        --password=${MONGO_PASSWORD} \
        --authenticationDatabase=admin \
        --db=${MONGO_DB} \
        --out=/tmp/backup 2>>"$LOG_FILE"; then
        
        if docker cp horizen-mongodb:/tmp/backup/. "$MONGO_BACKUP/" 2>>"$LOG_FILE"; then
            if [ -d "$MONGO_BACKUP" ] && [ "$(ls -A $MONGO_BACKUP)" ]; then
                if tar -czf "${MONGO_BACKUP}.tar.gz" -C "$BACKUP_DIR" "mongodb_${DATE}" 2>>"$LOG_FILE"; then
                    rm -rf "$MONGO_BACKUP"
                    MONGO_SIZE=$(du -h "${MONGO_BACKUP}.tar.gz" | cut -f1)
                    log "${GREEN}✓ MongoDB backup created: ${MONGO_BACKUP}.tar.gz (${MONGO_SIZE})${NC}"
                    # Cleanup temp files in container
                    docker-compose exec -T mongodb rm -rf /tmp/backup 2>>"$LOG_FILE" || true
                else
                    error_exit "Failed to compress MongoDB backup"
                    rm -rf "$MONGO_BACKUP"
                fi
            else
                error_exit "MongoDB backup directory is empty"
                rm -rf "$MONGO_BACKUP"
            fi
        else
            error_exit "Failed to copy MongoDB backup from container"
            rm -rf "$MONGO_BACKUP"
        fi
    else
        error_exit "MongoDB backup failed"
        rm -rf "$MONGO_BACKUP"
    fi
else
    error_exit "Failed to create MongoDB backup directory"
fi

# Backup Druid deep storage
log "\n${YELLOW}Backing up Druid segments...${NC}"
DRUID_BACKUP="$BACKUP_DIR/druid_segments_${DATE}.tar.gz"

# Get the actual volume name
VOLUME_NAME=$(docker volume ls --format '{{.Name}}' | grep druid-data | head -1)

if [ -n "$VOLUME_NAME" ]; then
    if docker-compose exec -T druid-coordinator test -d /opt/druid/var/druid/segments 2>/dev/null; then
        if docker run --rm \
            -v "${VOLUME_NAME}:/data" \
            -v "$BACKUP_DIR:/backup" \
            alpine tar -czf "/backup/druid_segments_${DATE}.tar.gz" -C /data druid/segments 2>>"$LOG_FILE"; then
            if [ -f "$DRUID_BACKUP" ] && [ -s "$DRUID_BACKUP" ]; then
                DRUID_SIZE=$(du -h "$DRUID_BACKUP" | cut -f1)
                log "${GREEN}✓ Druid segments backup created: $DRUID_BACKUP (${DRUID_SIZE})${NC}"
            else
                warning "Druid backup file is empty or not created"
            fi
        else
            warning "Failed to create Druid segments backup"
        fi
    else
        warning "No Druid segments directory found"
    fi
else
    warning "Could not find Druid data volume"
fi

# Backup configuration files
log "\n${YELLOW}Backing up configuration files...${NC}"
CONFIG_BACKUP="$BACKUP_DIR/config_${DATE}.tar.gz"

if tar -czf "$CONFIG_BACKUP" \
    --exclude='*.log' \
    --exclude='volumes' \
    --exclude='backups' \
    --exclude='.git' \
    nginx/ druid/ .env.example docker-compose*.yml 2>>"$LOG_FILE"; then
    if [ -f "$CONFIG_BACKUP" ] && [ -s "$CONFIG_BACKUP" ]; then
        CONFIG_SIZE=$(du -h "$CONFIG_BACKUP" | cut -f1)
        log "${GREEN}✓ Configuration backup created: $CONFIG_BACKUP (${CONFIG_SIZE})${NC}"
    else
        error_exit "Configuration backup file is empty or not created"
    fi
else
    error_exit "Configuration backup failed"
fi

# Clean old backups
log "\n${YELLOW}Cleaning old backups (older than ${RETENTION_DAYS} days)...${NC}"
DELETED_COUNT=0
DELETED_COUNT=$((DELETED_COUNT + $(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete -print 2>>"$LOG_FILE" | wc -l)))
DELETED_COUNT=$((DELETED_COUNT + $(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete -print 2>>"$LOG_FILE" | wc -l)))
DELETED_COUNT=$((DELETED_COUNT + $(find "$BACKUP_DIR" -name "*.log" -mtime +${RETENTION_DAYS} -delete -print 2>>"$LOG_FILE" | wc -l)))

if [ $DELETED_COUNT -gt 0 ]; then
    log "${GREEN}✓ Cleaned $DELETED_COUNT old backup files${NC}"
else
    log "${GREEN}✓ No old backups to clean${NC}"
fi

# Verify backup integrity
log "\n${YELLOW}Verifying backup integrity...${NC}"
VERIFICATION_ERRORS=0

[ -f "${POSTGRES_BACKUP}.gz" ] && gzip -t "${POSTGRES_BACKUP}.gz" 2>>"$LOG_FILE" || ((VERIFICATION_ERRORS++))
[ -f "${MONGO_BACKUP}.tar.gz" ] && tar -tzf "${MONGO_BACKUP}.tar.gz" >/dev/null 2>>"$LOG_FILE" || ((VERIFICATION_ERRORS++))
[ -f "$CONFIG_BACKUP" ] && tar -tzf "$CONFIG_BACKUP" >/dev/null 2>>"$LOG_FILE" || ((VERIFICATION_ERRORS++))

if [ $VERIFICATION_ERRORS -eq 0 ]; then
    log "${GREEN}✓ All backups verified successfully${NC}"
else
    error_exit "Backup verification found $VERIFICATION_ERRORS errors"
fi

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
CURRENT_BACKUP_SIZE=$(du -ch "$BACKUP_DIR"/*_${DATE}.* 2>/dev/null | tail -1 | cut -f1)

# Write backup metadata
METADATA_FILE="$BACKUP_DIR/backup_${DATE}.meta"
cat > "$METADATA_FILE" << EOF
Backup Date: $(date)
Backup ID: $DATE
Total Backup Size: $CURRENT_BACKUP_SIZE
PostgreSQL: $([ -f "${POSTGRES_BACKUP}.gz" ] && echo "SUCCESS" || echo "FAILED")
MongoDB: $([ -f "${MONGO_BACKUP}.tar.gz" ] && echo "SUCCESS" || echo "FAILED")
Druid: $([ -f "$DRUID_BACKUP" ] && echo "SUCCESS" || echo "WARNING")
Configuration: $([ -f "$CONFIG_BACKUP" ] && echo "SUCCESS" || echo "FAILED")
Errors: $BACKUP_ERRORS
Warnings: $BACKUP_WARNINGS
EOF

log "\n${GREEN}=== Backup Complete ===${NC}"
log "Current backup size: $CURRENT_BACKUP_SIZE"
log "Total backup directory size: $BACKUP_SIZE"
log "Backups location: $BACKUP_DIR"
log "Log file: $LOG_FILE"
log "Metadata: $METADATA_FILE"

# List recent backups
log "\n${YELLOW}Recent backups:${NC}"
ls -lh "$BACKUP_DIR" | grep "_${DATE}" | tee -a "$LOG_FILE"

# Exit with appropriate status
if [ $BACKUP_ERRORS -gt 0 ]; then
    log "\n${RED}Backup completed with $BACKUP_ERRORS error(s) and $BACKUP_WARNINGS warning(s)${NC}"
    exit 1
elif [ $BACKUP_WARNINGS -gt 0 ]; then
    log "\n${YELLOW}Backup completed with $BACKUP_WARNINGS warning(s)${NC}"
    exit 0
else
    log "\n${GREEN}Backup completed successfully!${NC}"
    exit 0
fi
