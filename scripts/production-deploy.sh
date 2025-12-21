#!/bin/bash

# Horizen Network Production Deployment Script
# Complete production deployment with all checks and safety measures

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Production Deployment ===${NC}\n"

# Configuration
ENVIRONMENT="production"
BACKUP_BEFORE_DEPLOY=true
RUN_MIGRATIONS=true
SKIP_VALIDATION=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --no-backup)
            BACKUP_BEFORE_DEPLOY=false
            shift
            ;;
        --no-migrations)
            RUN_MIGRATIONS=false
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Step 1: Pre-deployment validation
if [ "$SKIP_VALIDATION" = false ]; then
    echo -e "${BLUE}Step 1/8: Pre-deployment validation${NC}"
    if ./scripts/validate.sh; then
        echo -e "${GREEN}✓ Validation passed${NC}\n"
    else
        echo -e "${RED}✗ Validation failed. Fix errors before deploying.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Skipping validation (--skip-validation)${NC}\n"
fi

# Step 2: Backup current state
if [ "$BACKUP_BEFORE_DEPLOY" = true ]; then
    echo -e "${BLUE}Step 2/8: Creating pre-deployment backup${NC}"
    if ./scripts/backup.sh; then
        echo -e "${GREEN}✓ Backup created${NC}\n"
    else
        echo -e "${RED}✗ Backup failed${NC}"
        read -p "Continue without backup? (yes/no): " continue_deploy
        if [ "$continue_deploy" != "yes" ]; then
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}Skipping backup (--no-backup)${NC}\n"
fi

# Step 3: Pull latest code
echo -e "${BLUE}Step 3/8: Pulling latest code${NC}"
git pull origin main
echo -e "${GREEN}✓ Code updated${NC}\n"

# Step 4: Pull Docker images
echo -e "${BLUE}Step 4/8: Pulling Docker images${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml pull
echo -e "${GREEN}✓ Images pulled${NC}\n"

# Step 5: Run database migrations
if [ "$RUN_MIGRATIONS" = true ]; then
    echo -e "${BLUE}Step 5/8: Running database migrations${NC}"
    if ./migrations/run-migrations.sh; then
        echo -e "${GREEN}✓ Migrations completed${NC}\n"
    else
        echo -e "${RED}✗ Migrations failed${NC}"
        echo -e "${YELLOW}Rolling back...${NC}"
        ./scripts/rollback.sh --force
        exit 1
    fi
else
    echo -e "${YELLOW}Skipping migrations (--no-migrations)${NC}\n"
fi

# Step 6: Deploy services
echo -e "${BLUE}Step 6/8: Deploying services${NC}"
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --remove-orphans
echo -e "${GREEN}✓ Services deployed${NC}\n"

# Step 7: Wait and health check
echo -e "${BLUE}Step 7/8: Waiting for services to start${NC}"
echo -e "Waiting 60 seconds for services to initialize..."
sleep 60

echo -e "\nRunning health check..."
if ./scripts/health-check.sh; then
    echo -e "${GREEN}✓ All services healthy${NC}\n"
else
    echo -e "${RED}✗ Health check failed${NC}"
    echo -e "${YELLOW}Starting automatic rollback...${NC}"
    ./scripts/rollback.sh --force
    exit 1
fi

# Step 8: Post-deployment tasks
echo -e "${BLUE}Step 8/8: Post-deployment tasks${NC}"

# Clean up old Docker images
echo -e "Cleaning up old Docker images..."
docker image prune -f
echo -e "${GREEN}✓ Cleanup complete${NC}"

# Display deployment info
echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
echo -e "\nDeployment Information:"
echo -e "  Environment: ${GREEN}$ENVIRONMENT${NC}"
echo -e "  Git Commit: ${GREEN}$(git rev-parse --short HEAD)${NC}"
echo -e "  Git Branch: ${GREEN}$(git rev-parse --abbrev-ref HEAD)${NC}"
echo -e "  Deploy Time: ${GREEN}$(date)${NC}"

echo -e "\n${BLUE}Service URLs:${NC}"
echo -e "  Main Site: ${GREEN}https://$(grep DOMAIN .env | cut -d '=' -f2)${NC}"
echo -e "  Druid: ${GREEN}https://druid.$(grep DOMAIN .env | cut -d '=' -f2)${NC}"
echo -e "  Geniess: ${GREEN}https://geniess.$(grep DOMAIN .env | cut -d '=' -f2)${NC}"
echo -e "  Entity: ${GREEN}https://entity.$(grep DOMAIN .env | cut -d '=' -f2)${NC}"

echo -e "\n${YELLOW}Post-Deployment Checklist:${NC}"
echo -e "  [ ] Verify all services are accessible"
echo -e "  [ ] Test payment integration"
echo -e "  [ ] Check monitoring dashboards"
echo -e "  [ ] Review application logs"
echo -e "  [ ] Test subscription workflows"
echo -e "  [ ] Verify SSL certificates"

echo -e "\n${GREEN}Deployment successful!${NC}"
