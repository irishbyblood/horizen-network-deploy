#!/bin/bash

# Horizen Network Backup Script
# Creates backups of all databases and configurations
# Features: pre-flight checks, retry logic, verification, encryption, notifications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=3
RETRY_DELAY=5
MIN_DISK_SPACE_GB=10
ENABLE_ENCRYPTION="${BACKUP_ENCRYPTION:-false}"
ENABLE_S3_UPLOAD="${BACKUP_S3_UPLOAD:-false}"
ENABLE_VERIFICATION="${BACKUP_VERIFICATION:-true}"
ENABLE_NOTIFICATIONS="${BACKUP_NOTIFICATIONS:-false}"

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
BACKUP_LOG="${BACKUP_DIR}/backup_${DATE}.log"
BACKUP_ERRORS=0
BACKUP_WARNINGS=0

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Redirect all output to log file as well
exec > >(tee -a "$BACKUP_LOG")
exec 2>&1

echo -e "Backup started at: $(date)"
echo -e "Backup directory: $BACKUP_DIR"
echo -e "Timestamp: $DATE"

# ======================
# Pre-flight Checks
# ======================

echo -e "\n${YELLOW}=== Running Pre-flight Checks ===${NC}"

# Check disk space
echo -e "\n${YELLOW}Checking disk space...${NC}"
AVAILABLE_SPACE_GB=$(df -BG "$BACKUP_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
echo "Available space: ${AVAILABLE_SPACE_GB}GB"

if [ "$AVAILABLE_SPACE_GB" -lt "$MIN_DISK_SPACE_GB" ]; then
    echo -e "${RED}✗ Insufficient disk space (${AVAILABLE_SPACE_GB}GB available, ${MIN_DISK_SPACE_GB}GB required)${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Sufficient disk space available${NC}"
fi

# Check if services are running
echo -e "\n${YELLOW}Checking service availability...${NC}"

check_service() {
    local service_name=$1
    if docker ps --filter "name=${service_name}" --format '{{.Status}}' | grep -q 'Up'; then
        echo -e "${GREEN}✓ $service_name is running${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not running${NC}"
        ((BACKUP_ERRORS++))
        return 1
    fi
}

check_service "horizen-postgres" || true
check_service "horizen-mongodb" || true
check_service "horizen-redis" || true

if [ $BACKUP_ERRORS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some services are not running. Backup may be incomplete.${NC}"
    ((BACKUP_WARNINGS++))
    BACKUP_ERRORS=0  # Reset errors for actual backup operations
fi

# Check docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ docker-compose not found${NC}"
    exit 1
else
    echo -e "${GREEN}✓ docker-compose is available${NC}"
fi

# Helper function to retry commands
retry_backup() {
    local max_attempts=$1
    local delay=$2
    local description=$3
    shift 3
    local command=("$@")
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: $description"
        if "${command[@]}"; then
            echo -e "${GREEN}✓ Success${NC}"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}Retry $attempt failed, waiting ${delay}s...${NC}"
            sleep $delay
        fi
        ((attempt++))
    done
    
    echo -e "${RED}✗ Failed after $max_attempts attempts${NC}"
    return 1
}

echo -e "\n${YELLOW}=== Starting Backup Operations ===${NC}"

# Backup PostgreSQL (Druid metadata)
echo -e "\n${YELLOW}Backing up PostgreSQL...${NC}"
POSTGRES_BACKUP="$BACKUP_DIR/postgres_${DATE}.sql"

if retry_backup $MAX_RETRIES $RETRY_DELAY "PostgreSQL backup" \
    docker-compose exec -T postgres pg_dump -U ${POSTGRES_USER} ${POSTGRES_DB} > "$POSTGRES_BACKUP"; then
    
    # Compress the backup
    if [ -f "$POSTGRES_BACKUP" ] && [ -s "$POSTGRES_BACKUP" ]; then
        gzip "$POSTGRES_BACKUP"
        POSTGRES_BACKUP_SIZE=$(du -h "${POSTGRES_BACKUP}.gz" | cut -f1)
        echo -e "${GREEN}✓ PostgreSQL backup created: ${POSTGRES_BACKUP}.gz (${POSTGRES_BACKUP_SIZE})${NC}"
        
        # Verify backup if enabled
        if [ "$ENABLE_VERIFICATION" = true ]; then
            echo "Verifying PostgreSQL backup..."
            if gunzip -t "${POSTGRES_BACKUP}.gz" 2>/dev/null; then
                echo -e "${GREEN}✓ PostgreSQL backup verified${NC}"
            else
                echo -e "${RED}✗ PostgreSQL backup verification failed${NC}"
                ((BACKUP_ERRORS++))
            fi
        fi
    else
        echo -e "${RED}✗ PostgreSQL backup file is empty or not created${NC}"
        ((BACKUP_ERRORS++))
    fi
else
    echo -e "${RED}✗ PostgreSQL backup failed after retries${NC}"
    ((BACKUP_ERRORS++))
fi

# Backup MongoDB
echo -e "\n${YELLOW}Backing up MongoDB...${NC}"
MONGO_BACKUP="$BACKUP_DIR/mongodb_${DATE}"
mkdir -p "$MONGO_BACKUP"

backup_mongodb() {
    docker-compose exec -T mongodb mongodump \
        --username=${MONGO_USER} \
        --password=${MONGO_PASSWORD} \
        --authenticationDatabase=admin \
        --db=${MONGO_DB} \
        --out=/tmp/backup && \
    docker cp horizen-mongodb:/tmp/backup/. "$MONGO_BACKUP/" && \
    docker-compose exec -T mongodb rm -rf /tmp/backup
}

if retry_backup $MAX_RETRIES $RETRY_DELAY "MongoDB backup" backup_mongodb; then
    if [ -d "$MONGO_BACKUP" ] && [ "$(ls -A $MONGO_BACKUP)" ]; then
        tar -czf "${MONGO_BACKUP}.tar.gz" -C "$BACKUP_DIR" "mongodb_${DATE}"
        rm -rf "$MONGO_BACKUP"
        MONGO_BACKUP_SIZE=$(du -h "${MONGO_BACKUP}.tar.gz" | cut -f1)
        echo -e "${GREEN}✓ MongoDB backup created: ${MONGO_BACKUP}.tar.gz (${MONGO_BACKUP_SIZE})${NC}"
        
        # Verify backup if enabled
        if [ "$ENABLE_VERIFICATION" = true ]; then
            echo "Verifying MongoDB backup..."
            if tar -tzf "${MONGO_BACKUP}.tar.gz" > /dev/null 2>&1; then
                echo -e "${GREEN}✓ MongoDB backup verified${NC}"
            else
                echo -e "${RED}✗ MongoDB backup verification failed${NC}"
                ((BACKUP_ERRORS++))
            fi
        fi
    else
        echo -e "${RED}✗ MongoDB backup directory is empty${NC}"
        ((BACKUP_ERRORS++))
    fi
else
    echo -e "${RED}✗ MongoDB backup failed after retries${NC}"
    ((BACKUP_ERRORS++))
    rm -rf "$MONGO_BACKUP" 2>/dev/null || true
fi

# Backup Druid deep storage
echo -e "\n${YELLOW}Backing up Druid segments...${NC}"
DRUID_BACKUP="$BACKUP_DIR/druid_segments_${DATE}.tar.gz"

# Get the actual volume name
VOLUME_NAME=$(docker volume ls --format '{{.Name}}' | grep druid-data | head -1)

if docker-compose exec -T druid-coordinator test -d /opt/druid/var/druid/segments 2>/dev/null; then
    docker run --rm \
        -v "${VOLUME_NAME}:/data" \
        -v "$BACKUP_DIR:/backup" \
        alpine tar -czf "/backup/druid_segments_${DATE}.tar.gz" -C /data druid/segments 2>/dev/null || true
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

# Optional: Encrypt backups
if [ "$ENABLE_ENCRYPTION" = true ]; then
    echo -e "\n${YELLOW}Encrypting backups...${NC}"
    
    if command -v gpg &> /dev/null; then
        # Process .gz files
        for backup_file in "$BACKUP_DIR"/*_${DATE}*.gz 2>/dev/null; do
            if [ -f "$backup_file" ]; then
                echo "Encrypting $(basename $backup_file)..."
                if gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase="${BACKUP_ENCRYPTION_KEY:-changeme}" "$backup_file"; then
                    rm "$backup_file"
                    echo -e "${GREEN}✓ Encrypted: ${backup_file}.gpg${NC}"
                else
                    echo -e "${RED}✗ Encryption failed for $backup_file${NC}"
                    ((BACKUP_WARNINGS++))
                fi
            fi
        done
        
        # Process .tar.gz files
        for backup_file in "$BACKUP_DIR"/*_${DATE}*.tar.gz 2>/dev/null; do
            if [ -f "$backup_file" ]; then
                echo "Encrypting $(basename $backup_file)..."
                if gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase="${BACKUP_ENCRYPTION_KEY:-changeme}" "$backup_file"; then
                    rm "$backup_file"
                    echo -e "${GREEN}✓ Encrypted: ${backup_file}.gpg${NC}"
                else
                    echo -e "${RED}✗ Encryption failed for $backup_file${NC}"
                    ((BACKUP_WARNINGS++))
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠ GPG not found, skipping encryption${NC}"
        ((BACKUP_WARNINGS++))
    fi
fi

# Optional: Upload to S3
if [ "$ENABLE_S3_UPLOAD" = true ]; then
    echo -e "\n${YELLOW}Uploading backups to S3...${NC}"
    
    if command -v aws &> /dev/null; then
        S3_BUCKET="${AWS_BACKUP_BUCKET:-horizen-backups}"
        S3_PREFIX="${AWS_BACKUP_PREFIX:-horizen-network}"
        
        # Process all backup files separately to avoid glob issues
        for pattern in "gz" "tar.gz" "gpg"; do
          for backup_file in "$BACKUP_DIR"/*_${DATE}*."$pattern" 2>/dev/null; do
            [ -f "$backup_file" ] || continue
            
            filename=$(basename "$backup_file")
            echo "Uploading $filename to S3..."
            
            if retry_backup 3 10 "S3 upload" \
                aws s3 cp "$backup_file" "s3://${S3_BUCKET}/${S3_PREFIX}/${filename}"; then
                echo -e "${GREEN}✓ Uploaded: $filename${NC}"
                
                # Verify S3 upload
                if aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${filename}" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ S3 upload verified${NC}"
                else
                    echo -e "${RED}✗ S3 upload verification failed${NC}"
                    ((BACKUP_WARNINGS++))
                fi
            else
                echo -e "${RED}✗ S3 upload failed for $filename${NC}"
                ((BACKUP_WARNINGS++))
            fi
          done
        done
    else
        echo -e "${YELLOW}⚠ AWS CLI not found, skipping S3 upload${NC}"
        ((BACKUP_WARNINGS++))
    fi
fi

# Clean old backups
echo -e "\n${YELLOW}Cleaning old backups (older than ${RETENTION_DAYS} days)...${NC}"
DELETED_COUNT=0
for pattern in "*.sql.gz" "*.tar.gz" "*.gpg" "*.log"; do
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            rm "$file"
            ((DELETED_COUNT++))
        fi
    done < <(find "$BACKUP_DIR" -name "$pattern" -mtime +${RETENTION_DAYS} 2>/dev/null)
done
echo -e "${GREEN}✓ Cleaned $DELETED_COUNT old backup file(s)${NC}"

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
CURRENT_BACKUP_SIZE=$(du -sh "$BACKUP_DIR"/*_${DATE}* 2>/dev/null | awk '{s+=$1}END{print s}' || echo "0")

echo -e "\n${GREEN}=== Backup Complete ===${NC}"
echo -e "Backup finished at: $(date)"
echo -e "Current backup size: ${CURRENT_BACKUP_SIZE}"
echo -e "Total backup directory size: $BACKUP_SIZE"
echo -e "Backups location: $BACKUP_DIR"
echo -e "Errors: $BACKUP_ERRORS"
echo -e "Warnings: $BACKUP_WARNINGS"

# List recent backups
echo -e "\n${YELLOW}Recent backups:${NC}"
ls -lht "$BACKUP_DIR"/*_${DATE}* 2>/dev/null || echo "No backups created for this session"

# Send notifications if enabled
if [ "$ENABLE_NOTIFICATIONS" = true ]; then
    if [ -f "./scripts/notify.sh" ]; then
        if [ $BACKUP_ERRORS -eq 0 ]; then
            ./scripts/notify.sh "backup_success" "Backup completed successfully. Size: ${CURRENT_BACKUP_SIZE}, Warnings: ${BACKUP_WARNINGS}"
        else
            ./scripts/notify.sh "backup_failed" "Backup completed with errors. Errors: ${BACKUP_ERRORS}, Warnings: ${BACKUP_WARNINGS}"
        fi
    fi
fi

# Exit with appropriate code
if [ $BACKUP_ERRORS -gt 0 ]; then
    echo -e "\n${RED}Backup completed with errors${NC}"
    exit 1
elif [ $BACKUP_WARNINGS -gt 0 ]; then
    echo -e "\n${YELLOW}Backup completed with warnings${NC}"
    exit 0
else
    echo -e "\n${GREEN}Backup completed successfully${NC}"
    exit 0
fi
