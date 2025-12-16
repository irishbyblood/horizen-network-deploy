#!/bin/bash

# Horizen Network Pre-Deployment Validation Script
# Validates prerequisites before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Pre-Deployment Validation ===${NC}\n"

ERRORS=0
WARNINGS=0
CHECKS=0

# Function to check command
check_command() {
    local cmd=$1
    local required=${2:-true}
    
    ((CHECKS++))
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -1)
        echo -e "${GREEN}✓ $cmd is installed${NC} ($version)"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗ $cmd is not installed (REQUIRED)${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}! $cmd is not installed (optional)${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check file
check_file() {
    local file=$1
    local required=${2:-true}
    
    ((CHECKS++))
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗ $file not found (REQUIRED)${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}! $file not found (optional)${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check environment variable
check_env_var() {
    local var=$1
    local required=${2:-true}
    
    ((CHECKS++))
    if [ -n "${!var}" ]; then
        echo -e "${GREEN}✓ $var is set${NC}"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗ $var is not set (REQUIRED)${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}! $var is not set (optional)${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Check required commands
echo -e "${YELLOW}Checking required commands...${NC}"
check_command docker
check_command docker-compose
check_command git
check_command curl

echo -e "\n${YELLOW}Checking optional commands...${NC}"
check_command certbot false
check_command psql false
check_command mongosh false

# Check Docker daemon
echo -e "\n${YELLOW}Checking Docker daemon...${NC}"
((CHECKS++))
if docker info &> /dev/null; then
    echo -e "${GREEN}✓ Docker daemon is running${NC}"
else
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    ((ERRORS++))
fi

# Check required files
echo -e "\n${YELLOW}Checking required files...${NC}"
check_file ".env"
check_file "docker-compose.yml"
check_file "nginx/nginx.conf"
check_file "scripts/deploy.sh"
check_file "scripts/health-check.sh"

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Check required environment variables
echo -e "\n${YELLOW}Checking environment variables...${NC}"
check_env_var "DOMAIN"
check_env_var "POSTGRES_PASSWORD"
check_env_var "MONGO_PASSWORD"
check_env_var "REDIS_PASSWORD"
check_env_var "ADMIN_EMAIL"

# Check payment-related environment variables
echo -e "\n${YELLOW}Checking payment environment variables...${NC}"
check_env_var "STRIPE_SECRET_KEY" false
check_env_var "STRIPE_WEBHOOK_SECRET" false

# Check disk space
echo -e "\n${YELLOW}Checking system resources...${NC}"
((CHECKS++))
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓ Disk space OK ($DISK_USAGE% used)${NC}"
else
    echo -e "${RED}✗ Disk space critical ($DISK_USAGE% used)${NC}"
    ((ERRORS++))
fi

# Check memory
((CHECKS++))
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -ge 8 ]; then
    echo -e "${GREEN}✓ Memory OK (${TOTAL_MEM}GB)${NC}"
else
    echo -e "${YELLOW}! Low memory (${TOTAL_MEM}GB, recommended: 8GB+)${NC}"
    ((WARNINGS++))
fi

# Check ports
echo -e "\n${YELLOW}Checking port availability...${NC}"
for port in 80 443; do
    ((CHECKS++))
    if ! sudo netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ Port $port is available${NC}"
    else
        echo -e "${RED}✗ Port $port is already in use${NC}"
        ((ERRORS++))
    fi
done

# Check DNS resolution (if domain is set)
if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "localhost" ]; then
    echo -e "\n${YELLOW}Checking DNS resolution...${NC}"
    ((CHECKS++))
    if host "$DOMAIN" &> /dev/null; then
        echo -e "${GREEN}✓ $DOMAIN resolves${NC}"
    else
        echo -e "${YELLOW}! $DOMAIN does not resolve (may not be configured yet)${NC}"
        ((WARNINGS++))
    fi
fi

# Check Docker Compose configuration
echo -e "\n${YELLOW}Checking Docker Compose configuration...${NC}"
((CHECKS++))
if docker-compose config &> /dev/null; then
    echo -e "${GREEN}✓ Docker Compose configuration is valid${NC}"
else
    echo -e "${RED}✗ Docker Compose configuration has errors${NC}"
    ((ERRORS++))
fi

# Summary
echo -e "\n${GREEN}=== Validation Summary ===${NC}"
echo -e "Total checks: $CHECKS"
echo -e "Passed: ${GREEN}$((CHECKS - ERRORS - WARNINGS))${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Errors: ${RED}$ERRORS${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All validation checks passed!${NC}"
    echo -e "${GREEN}System is ready for deployment.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "\n${YELLOW}Validation passed with warnings.${NC}"
    echo -e "${YELLOW}Review warnings above before proceeding.${NC}"
    exit 0
else
    echo -e "\n${RED}Validation failed with $ERRORS error(s).${NC}"
    echo -e "${RED}Please fix errors before deploying.${NC}"
    exit 1
fi
