#!/bin/bash

# Horizen Network Pre-Deployment Validation Script
# Validates environment, configuration, and system requirements before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network Pre-Deployment Validation ===${NC}"

ERRORS=0
WARNINGS=0

# Helper function for checks
check_pass() {
    echo -e "${GREEN}✓ $1${NC}"
}

check_fail() {
    echo -e "${RED}✗ $1${NC}"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNINGS++))
}

# ======================
# 1. Environment Variables Check
# ======================
echo -e "\n${YELLOW}=== Checking Environment Variables ===${NC}"

if [ ! -f .env ]; then
    check_fail ".env file not found"
    echo -e "${RED}Critical: Cannot proceed without .env file${NC}"
    exit 1
else
    check_pass ".env file exists"
    source .env
fi

# Required variables
REQUIRED_VARS=(
    "DOMAIN"
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "POSTGRES_DB"
    "MONGO_USER"
    "MONGO_PASSWORD"
    "MONGO_DB"
    "REDIS_PASSWORD"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        check_fail "Required variable $var is not set"
    else
        check_pass "Variable $var is set"
    fi
done

# Check for default passwords
if [[ "${POSTGRES_PASSWORD}" == *"changeme"* ]] || \
   [[ "${MONGO_PASSWORD}" == *"changeme"* ]] || \
   [[ "${REDIS_PASSWORD}" == *"changeme"* ]]; then
    check_warn "Default passwords detected - should be changed for production"
fi

# ======================
# 2. Configuration File Validation
# ======================
echo -e "\n${YELLOW}=== Validating Configuration Files ===${NC}"

# Validate Docker Compose files
for file in docker-compose.yml docker-compose.prod.yml docker-compose.dev.yml; do
    if [ -f "$file" ]; then
        if docker-compose -f "$file" config > /dev/null 2>&1; then
            check_pass "$file syntax is valid"
        else
            check_fail "$file has syntax errors"
        fi
    else
        check_warn "$file not found"
    fi
done

# Validate Nginx configuration
if [ -d "nginx/conf.d" ]; then
    if docker run --rm -v "$(pwd)/nginx:/etc/nginx:ro" nginx:alpine nginx -t > /dev/null 2>&1; then
        check_pass "Nginx configuration is valid"
    else
        check_fail "Nginx configuration has errors"
    fi
else
    check_fail "Nginx configuration directory not found"
fi

# Validate Kubernetes manifests (if present)
if [ -d "kubernetes" ]; then
    echo "Validating Kubernetes manifests..."
    for file in kubernetes/*.yaml kubernetes/**/*.yaml; do
        if [ -f "$file" ]; then
            if command -v kubectl &> /dev/null; then
                if kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
                    check_pass "$(basename $file) is valid"
                else
                    check_fail "$(basename $file) has validation errors"
                fi
            else
                # Fallback to basic YAML validation
                if command -v yq &> /dev/null || command -v python3 &> /dev/null; then
                    if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null || \
                       yq eval "$file" > /dev/null 2>&1; then
                        check_pass "$(basename $file) YAML syntax is valid"
                    else
                        check_fail "$(basename $file) has YAML syntax errors"
                    fi
                else
                    check_warn "$(basename $file) - cannot validate (kubectl, yq, or python3 not found)"
                fi
            fi
        fi
    done
fi

# ======================
# 3. Disk Space Requirements
# ======================
echo -e "\n${YELLOW}=== Checking Disk Space ===${NC}"

MIN_SPACE_GB=20
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')

echo "Available disk space: ${AVAILABLE_SPACE}GB"
if [ "$AVAILABLE_SPACE" -ge "$MIN_SPACE_GB" ]; then
    check_pass "Sufficient disk space (${AVAILABLE_SPACE}GB >= ${MIN_SPACE_GB}GB required)"
else
    check_fail "Insufficient disk space (${AVAILABLE_SPACE}GB < ${MIN_SPACE_GB}GB required)"
fi

# Check specific directories
for dir in "./backups" "./volumes"; do
    if [ -d "$dir" ]; then
        dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
        echo "  $dir: $dir_size"
    fi
done

# ======================
# 4. Network Connectivity
# ======================
echo -e "\n${YELLOW}=== Checking Network Connectivity ===${NC}"

# Check DNS resolution
if host google.com > /dev/null 2>&1; then
    check_pass "DNS resolution working"
else
    check_fail "DNS resolution failed"
fi

# Check if domain resolves (if not localhost)
if [ "$DOMAIN" != "localhost" ] && [ "$DOMAIN" != "127.0.0.1" ]; then
    if host "$DOMAIN" > /dev/null 2>&1; then
        RESOLVED_IP=$(host "$DOMAIN" | awk '/has address/ {print $4}' | head -1)
        check_pass "Domain $DOMAIN resolves to $RESOLVED_IP"
    else
        check_warn "Domain $DOMAIN does not resolve (may be fine for initial setup)"
    fi
fi

# Check internet connectivity
if curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
    check_pass "Internet connectivity available"
else
    check_warn "Limited internet connectivity (may affect image pulls)"
fi

# ======================
# 5. DNS Configuration Check
# ======================
echo -e "\n${YELLOW}=== Checking DNS Configuration ===${NC}"

if [ -n "$DOMAIN" ]; then
    echo "Main domain: $DOMAIN"
    if host "$DOMAIN" > /dev/null 2>&1; then
        check_pass "Main domain resolves"
    else
        check_warn "Main domain does not resolve yet"
    fi
fi

if [ -n "$DRUID_DOMAIN" ]; then
    echo "Druid domain: $DRUID_DOMAIN"
    if host "$DRUID_DOMAIN" > /dev/null 2>&1; then
        check_pass "Druid domain resolves"
    else
        check_warn "Druid domain does not resolve yet"
    fi
fi

# ======================
# 6. Port Availability
# ======================
echo -e "\n${YELLOW}=== Checking Port Availability ===${NC}"

PORTS=(80 443)

for port in "${PORTS[@]}"; do
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            check_warn "Port $port is already in use"
        else
            check_pass "Port $port is available"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            check_warn "Port $port is already in use"
        else
            check_pass "Port $port is available"
        fi
    else
        check_warn "Cannot check port $port (netstat/ss not available)"
    fi
done

# ======================
# 7. Docker and Docker Compose Version
# ======================
echo -e "\n${YELLOW}=== Checking Docker Environment ===${NC}"

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    check_pass "Docker installed (version: $DOCKER_VERSION)"
    
    # Check Docker is running
    if docker ps > /dev/null 2>&1; then
        check_pass "Docker daemon is running"
    else
        check_fail "Docker daemon is not running"
    fi
    
    # Check Docker version (minimum 20.10)
    DOCKER_MAJOR=$(echo $DOCKER_VERSION | cut -d. -f1)
    DOCKER_MINOR=$(echo $DOCKER_VERSION | cut -d. -f2)
    if [ "$DOCKER_MAJOR" -ge 20 ] && [ "$DOCKER_MINOR" -ge 10 ]; then
        check_pass "Docker version is sufficient (>= 20.10)"
    else
        check_warn "Docker version may be outdated (< 20.10)"
    fi
else
    check_fail "Docker is not installed"
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | awk '{print $4}' | sed 's/,//')
        check_pass "Docker Compose installed (version: $COMPOSE_VERSION)"
    else
        COMPOSE_VERSION=$(docker compose version | awk '{print $4}' | sed 's/,//')
        check_pass "Docker Compose (plugin) installed (version: $COMPOSE_VERSION)"
    fi
else
    check_fail "Docker Compose is not installed"
fi

# Check Docker storage driver
if command -v docker &> /dev/null && docker ps > /dev/null 2>&1; then
    STORAGE_DRIVER=$(docker info 2>/dev/null | grep "Storage Driver" | awk '{print $3}')
    if [ -n "$STORAGE_DRIVER" ]; then
        check_pass "Docker storage driver: $STORAGE_DRIVER"
    fi
fi

# ======================
# 8. System Resources
# ======================
echo -e "\n${YELLOW}=== Checking System Resources ===${NC}"

# Check CPU cores
CPU_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
if [ "$CPU_CORES" != "unknown" ]; then
    echo "CPU cores: $CPU_CORES"
    if [ "$CPU_CORES" -ge 4 ]; then
        check_pass "Sufficient CPU cores ($CPU_CORES >= 4)"
    else
        check_warn "Limited CPU cores ($CPU_CORES < 4 recommended)"
    fi
fi

# Check memory
TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
if [ -n "$TOTAL_MEM_KB" ]; then
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
    echo "Total memory: ${TOTAL_MEM_GB}GB"
    if [ "$TOTAL_MEM_GB" -ge 8 ]; then
        check_pass "Sufficient memory (${TOTAL_MEM_GB}GB >= 8GB)"
    else
        check_warn "Limited memory (${TOTAL_MEM_GB}GB < 8GB recommended)"
    fi
fi

# ======================
# 9. File Permissions
# ======================
echo -e "\n${YELLOW}=== Checking File Permissions ===${NC}"

# Check script executability
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            check_pass "$(basename $script) is executable"
        else
            check_warn "$(basename $script) is not executable - run: chmod +x $script"
        fi
    fi
done

# Check write permissions for critical directories
for dir in "." "./backups" "./volumes"; do
    if [ -d "$dir" ] || [ "$dir" = "." ]; then
        if [ -w "$dir" ]; then
            check_pass "Write permission for $dir"
        else
            check_fail "No write permission for $dir"
        fi
    fi
done

# ======================
# Summary
# ======================
echo -e "\n${GREEN}=== Validation Summary ===${NC}"
echo -e "Errors: $ERRORS"
echo -e "Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "\n${GREEN}✓ All validation checks passed!${NC}"
        echo -e "${GREEN}System is ready for deployment.${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}⚠ Validation passed with warnings${NC}"
        echo -e "${YELLOW}Review warnings before proceeding with deployment.${NC}"
        exit 0
    fi
else
    echo -e "\n${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo -e "${RED}Fix errors before attempting deployment.${NC}"
    exit 1
fi
