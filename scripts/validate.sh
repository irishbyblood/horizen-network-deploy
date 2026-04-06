#!/bin/bash

# Horizen Network Validation Script
# Pre-deployment validation checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Horizen Network Pre-Deployment Validation ===${NC}"

ERRORS=0
WARNINGS=0

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to report error
report_error() {
    echo -e "${RED}✗ $1${NC}"
    ((ERRORS++))
}

# Function to report warning
report_warning() {
    echo -e "${YELLOW}! $1${NC}"
    ((WARNINGS++))
}

# Function to report success
report_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 1. Check Required Commands
echo -e "\n${BLUE}Checking required commands...${NC}"

if command_exists docker; then
    DOCKER_VERSION=$(docker --version)
    report_success "Docker is installed: $DOCKER_VERSION"
else
    report_error "Docker is not installed"
fi

if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
    if command_exists docker-compose; then
        COMPOSE_VERSION=$(docker-compose --version)
    else
        COMPOSE_VERSION=$(docker compose version)
    fi
    report_success "Docker Compose is installed: $COMPOSE_VERSION"
else
    report_error "Docker Compose is not installed"
fi

if command_exists git; then
    GIT_VERSION=$(git --version)
    report_success "Git is installed: $GIT_VERSION"
else
    report_warning "Git is not installed (optional for production)"
fi

# 2. Check Environment Variables
echo -e "\n${BLUE}Checking environment variables...${NC}"

if [ ! -f .env ]; then
    report_error ".env file not found"
    echo -e "${YELLOW}  Create one from .env.example: cp .env.example .env${NC}"
else
    report_success ".env file exists"
    
    # Source environment file
    set -a
    source .env
    set +a
    
    # Check required variables
    REQUIRED_VARS=(
        "DOMAIN"
        "POSTGRES_PASSWORD"
        "MONGO_PASSWORD"
        "REDIS_PASSWORD"
        "ADMIN_EMAIL"
    )
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            report_error "Required variable $var is not set"
        else
            if [[ "${!var}" == *"changeme"* ]]; then
                report_warning "Variable $var contains 'changeme' - should be changed for production"
            else
                report_success "Variable $var is set"
            fi
        fi
    done
    
    # Check password strength
    if [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
        report_warning "POSTGRES_PASSWORD is less than 12 characters"
    fi
    
    if [ ${#MONGO_PASSWORD} -lt 12 ]; then
        report_warning "MONGO_PASSWORD is less than 12 characters"
    fi
    
    if [ ${#REDIS_PASSWORD} -lt 12 ]; then
        report_warning "REDIS_PASSWORD is less than 12 characters"
    fi
fi

# 3. Validate Docker Compose Files
echo -e "\n${BLUE}Validating Docker Compose files...${NC}"

if [ -f docker-compose.yml ]; then
    if docker-compose config > /dev/null 2>&1 || docker compose config > /dev/null 2>&1; then
        report_success "docker-compose.yml is valid"
    else
        report_error "docker-compose.yml has syntax errors"
    fi
else
    report_error "docker-compose.yml not found"
fi

if [ -f docker-compose.prod.yml ]; then
    if docker-compose -f docker-compose.yml -f docker-compose.prod.yml config > /dev/null 2>&1 || docker compose -f docker-compose.yml -f docker-compose.prod.yml config > /dev/null 2>&1; then
        report_success "docker-compose.prod.yml is valid"
    else
        report_error "docker-compose.prod.yml has syntax errors"
    fi
fi

if [ -f docker-compose.dev.yml ]; then
    if docker-compose -f docker-compose.yml -f docker-compose.dev.yml config > /dev/null 2>&1 || docker compose -f docker-compose.yml -f docker-compose.dev.yml config > /dev/null 2>&1; then
        report_success "docker-compose.dev.yml is valid"
    else
        report_error "docker-compose.dev.yml has syntax errors"
    fi
fi

# 4. Check System Resources
echo -e "\n${BLUE}Checking system resources...${NC}"

# Check disk space
DISK_AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$DISK_AVAILABLE" -lt 20 ]; then
    report_warning "Low disk space: ${DISK_AVAILABLE}GB available (recommend at least 20GB)"
else
    report_success "Disk space OK: ${DISK_AVAILABLE}GB available"
fi

# Check memory
MEMORY_TOTAL=$(free -g | awk '/^Mem:/{print $2}')
if [ "$MEMORY_TOTAL" -lt 4 ]; then
    report_warning "Low memory: ${MEMORY_TOTAL}GB total (recommend at least 8GB)"
elif [ "$MEMORY_TOTAL" -lt 8 ]; then
    report_warning "Memory OK but limited: ${MEMORY_TOTAL}GB total (recommend 16GB for production)"
else
    report_success "Memory OK: ${MEMORY_TOTAL}GB total"
fi

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
    report_warning "Low CPU cores: $CPU_CORES (recommend at least 4)"
elif [ "$CPU_CORES" -lt 4 ]; then
    report_warning "CPU cores OK but limited: $CPU_CORES (recommend 8 for production)"
else
    report_success "CPU cores OK: $CPU_CORES"
fi

# 5. Test Database Connections (if containers are running)
echo -e "\n${BLUE}Testing database connections...${NC}"

if docker ps --format '{{.Names}}' | grep -q horizen-postgres; then
    if docker exec horizen-postgres pg_isready -U ${POSTGRES_USER:-druid} > /dev/null 2>&1; then
        report_success "PostgreSQL is accessible"
    else
        report_error "PostgreSQL is not accessible"
    fi
else
    report_warning "PostgreSQL container not running (skipping connection test)"
fi

if docker ps --format '{{.Names}}' | grep -q horizen-mongodb; then
    if docker exec horizen-mongodb mongosh --quiet --eval "db.adminCommand('ping').ok" 2>/dev/null | grep -q "1"; then
        report_success "MongoDB is accessible"
    else
        report_error "MongoDB is not accessible"
    fi
else
    report_warning "MongoDB container not running (skipping connection test)"
fi

if docker ps --format '{{.Names}}' | grep -q horizen-redis; then
    if docker exec horizen-redis redis-cli -a ${REDIS_PASSWORD} ping 2>/dev/null | grep -q PONG; then
        report_success "Redis is accessible"
    else
        report_error "Redis is not accessible"
    fi
else
    report_warning "Redis container not running (skipping connection test)"
fi

# 6. Verify SSL Certificates (if enabled)
echo -e "\n${BLUE}Checking SSL configuration...${NC}"

if [ "${ENABLE_SSL}" = "true" ]; then
    if [ -n "${SSL_EMAIL}" ]; then
        report_success "SSL is enabled with email: $SSL_EMAIL"
        
        # Check if certificates exist
        if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
            CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
            if [ -f "$CERT_FILE" ]; then
                CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
                report_success "SSL certificate exists, expires: $CERT_EXPIRY"
            else
                report_warning "SSL certificate not found at $CERT_FILE"
            fi
        else
            report_warning "SSL certificate directory not found (may not be installed yet)"
        fi
    else
        report_error "SSL is enabled but SSL_EMAIL is not set"
    fi
else
    report_warning "SSL is disabled (ENABLE_SSL=false)"
fi

# 7. Check DNS Resolution
echo -e "\n${BLUE}Checking DNS resolution...${NC}"

if [ -n "${DOMAIN}" ]; then
    if command_exists dig; then
        DNS_IP=$(dig +short "${DOMAIN}" | head -1)
        if [ -n "$DNS_IP" ]; then
            report_success "Domain ${DOMAIN} resolves to: $DNS_IP"
            
            # Check if it resolves to this server
            if command_exists curl; then
                SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "unknown")
                if [ "$DNS_IP" = "$SERVER_IP" ]; then
                    report_success "Domain points to this server"
                else
                    report_warning "Domain points to $DNS_IP but server IP is $SERVER_IP"
                fi
            fi
        else
            report_warning "Domain ${DOMAIN} does not resolve"
        fi
    else
        report_warning "dig command not available (install dnsutils)"
    fi
else
    report_warning "DOMAIN not set in .env"
fi

# 8. Check Network Connectivity
echo -e "\n${BLUE}Checking network connectivity...${NC}"

if command_exists curl; then
    if curl -s --connect-timeout 5 https://www.google.com > /dev/null; then
        report_success "Internet connectivity OK"
    else
        report_error "No internet connectivity"
    fi
    
    # Check Docker Hub connectivity
    if curl -s --connect-timeout 5 https://hub.docker.com > /dev/null; then
        report_success "Docker Hub is accessible"
    else
        report_warning "Cannot reach Docker Hub"
    fi
else
    report_warning "curl not installed (cannot test connectivity)"
fi

# 9. Check Port Availability
echo -e "\n${BLUE}Checking port availability...${NC}"

PORTS_TO_CHECK=(80 443)

for port in "${PORTS_TO_CHECK[@]}"; do
    if command_exists netstat; then
        if netstat -tuln | grep -q ":$port "; then
            report_warning "Port $port is already in use"
        else
            report_success "Port $port is available"
        fi
    elif command_exists ss; then
        if ss -tuln | grep -q ":$port "; then
            report_warning "Port $port is already in use"
        else
            report_success "Port $port is available"
        fi
    else
        report_warning "Cannot check port $port (netstat/ss not available)"
    fi
done

# 10. Validate Nginx Configuration
echo -e "\n${BLUE}Validating Nginx configuration...${NC}"

if [ -f nginx/nginx.conf ]; then
    report_success "nginx/nginx.conf exists"
    
    # Test with Docker if Nginx container is running
    if docker ps --format '{{.Names}}' | grep -q horizen-nginx; then
        if docker exec horizen-nginx nginx -t 2>&1 | grep -q "successful"; then
            report_success "Nginx configuration is valid"
        else
            report_error "Nginx configuration has errors"
        fi
    else
        # Test with docker run if container not running
        if command_exists docker; then
            if docker run --rm -v "$(pwd)/nginx:/etc/nginx:ro" nginx:alpine nginx -t 2>&1 | grep -q "successful"; then
                report_success "Nginx configuration syntax is valid"
            else
                report_error "Nginx configuration has syntax errors"
            fi
        fi
    fi
else
    report_error "nginx/nginx.conf not found"
fi

# 11. Check Docker Daemon
echo -e "\n${BLUE}Checking Docker daemon...${NC}"

if docker info > /dev/null 2>&1; then
    report_success "Docker daemon is running"
    
    # Check Docker storage driver
    STORAGE_DRIVER=$(docker info 2>/dev/null | grep "Storage Driver" | cut -d: -f2 | tr -d ' ')
    if [ "$STORAGE_DRIVER" = "overlay2" ]; then
        report_success "Using recommended storage driver: overlay2"
    else
        report_warning "Storage driver is $STORAGE_DRIVER (overlay2 is recommended)"
    fi
else
    report_error "Docker daemon is not running"
fi

# 12. Check File Permissions
echo -e "\n${BLUE}Checking file permissions...${NC}"

if [ -x scripts/deploy.sh ]; then
    report_success "scripts/deploy.sh is executable"
else
    report_warning "scripts/deploy.sh is not executable (run: chmod +x scripts/deploy.sh)"
fi

if [ -x scripts/health-check.sh ]; then
    report_success "scripts/health-check.sh is executable"
else
    report_warning "scripts/health-check.sh is not executable (run: chmod +x scripts/health-check.sh)"
fi

if [ -x scripts/backup.sh ]; then
    report_success "scripts/backup.sh is executable"
else
    report_warning "scripts/backup.sh is not executable (run: chmod +x scripts/backup.sh)"
fi

# Summary
echo -e "\n${BLUE}=== Validation Summary ===${NC}"
echo -e "Errors: $ERRORS"
echo -e "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All validation checks passed!${NC}"
        echo -e "${GREEN}✓ System is ready for deployment${NC}"
        exit 0
    else
        echo -e "${YELLOW}! Validation passed with warnings${NC}"
        echo -e "${YELLOW}! Review warnings before deploying to production${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo -e "${RED}✗ Please fix errors before deployment${NC}"
    exit 1
fi
