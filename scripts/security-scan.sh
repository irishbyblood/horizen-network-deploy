#!/bin/bash

# Horizen Network Security Scanning Script
# Scans for vulnerabilities and security issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Horizen Network Security Scan ===${NC}"

CRITICAL=0
HIGH=0
MEDIUM=0
LOW=0
INFO=0

# Function to report finding
report_finding() {
    local severity="$1"
    local message="$2"
    
    case $severity in
        CRITICAL)
            echo -e "${RED}[CRITICAL] $message${NC}"
            ((CRITICAL++))
            ;;
        HIGH)
            echo -e "${RED}[HIGH] $message${NC}"
            ((HIGH++))
            ;;
        MEDIUM)
            echo -e "${YELLOW}[MEDIUM] $message${NC}"
            ((MEDIUM++))
            ;;
        LOW)
            echo -e "${YELLOW}[LOW] $message${NC}"
            ((LOW++))
            ;;
        INFO)
            echo -e "${BLUE}[INFO] $message${NC}"
            ((INFO++))
            ;;
        PASS)
            echo -e "${GREEN}[PASS] $message${NC}"
            ;;
    esac
}

# 1. Docker Image Vulnerability Scanning
echo -e "\n${BLUE}=== Docker Image Vulnerability Scan ===${NC}"

if command -v trivy >/dev/null 2>&1; then
    echo -e "${YELLOW}Scanning Docker images with Trivy...${NC}"
    
    # Get list of images used in docker-compose
    IMAGES=$(docker-compose config | grep "image:" | awk '{print $2}' | sort | uniq)
    
    for image in $IMAGES; do
        echo -e "\n${YELLOW}Scanning: $image${NC}"
        
        # Run Trivy scan
        SCAN_RESULT=$(trivy image --quiet --severity HIGH,CRITICAL "$image" 2>/dev/null || echo "SCAN_FAILED")
        
        if [ "$SCAN_RESULT" = "SCAN_FAILED" ]; then
            report_finding "INFO" "Could not scan image: $image"
        else
            CRITICAL_VULNS=$(echo "$SCAN_RESULT" | grep -c "CRITICAL" || echo "0")
            HIGH_VULNS=$(echo "$SCAN_RESULT" | grep -c "HIGH" || echo "0")
            
            if [ "$CRITICAL_VULNS" -gt 0 ]; then
                report_finding "CRITICAL" "$image has $CRITICAL_VULNS critical vulnerabilities"
            elif [ "$HIGH_VULNS" -gt 0 ]; then
                report_finding "HIGH" "$image has $HIGH_VULNS high vulnerabilities"
            else
                report_finding "PASS" "$image has no critical or high vulnerabilities"
            fi
        fi
    done
else
    report_finding "INFO" "Trivy not installed. Install with: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
fi

# 2. Configuration Security Checks
echo -e "\n${BLUE}=== Configuration Security Checks ===${NC}"

# Check .env file permissions
if [ -f .env ]; then
    PERMS=$(stat -c "%a" .env 2>/dev/null || stat -f "%OLp" .env 2>/dev/null || echo "000")
    if [ "$PERMS" = "600" ] || [ "$PERMS" = "400" ]; then
        report_finding "PASS" ".env file has secure permissions ($PERMS)"
    else
        report_finding "MEDIUM" ".env file has insecure permissions ($PERMS). Should be 600 or 400"
    fi
else
    report_finding "INFO" ".env file not found"
fi

# Check for default passwords
if [ -f .env ]; then
    set -a
    source .env
    set +a
    
    if [[ "$POSTGRES_PASSWORD" == *"changeme"* ]]; then
        report_finding "CRITICAL" "PostgreSQL password contains 'changeme'"
    fi
    
    if [[ "$MONGO_PASSWORD" == *"changeme"* ]]; then
        report_finding "CRITICAL" "MongoDB password contains 'changeme'"
    fi
    
    if [[ "$REDIS_PASSWORD" == *"changeme"* ]]; then
        report_finding "CRITICAL" "Redis password contains 'changeme'"
    fi
    
    # Check password length
    if [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
        report_finding "HIGH" "PostgreSQL password is less than 12 characters"
    fi
    
    if [ ${#MONGO_PASSWORD} -lt 12 ]; then
        report_finding "HIGH" "MongoDB password is less than 12 characters"
    fi
    
    if [ ${#REDIS_PASSWORD} -lt 12 ]; then
        report_finding "HIGH" "Redis password is less than 12 characters"
    fi
fi

# Check SSL configuration
if [ "${ENABLE_SSL}" = "false" ] && [ "${ENVIRONMENT}" = "production" ]; then
    report_finding "HIGH" "SSL is disabled in production environment"
fi

# Check if debug mode is enabled in production
if [ "${ENABLE_DEBUG}" = "true" ] && [ "${ENVIRONMENT}" = "production" ]; then
    report_finding "MEDIUM" "Debug mode is enabled in production"
fi

# 3. Secrets Scanning
echo -e "\n${BLUE}=== Secrets Scanning ===${NC}"

if command -v gitleaks >/dev/null 2>&1; then
    echo -e "${YELLOW}Scanning for secrets with gitleaks...${NC}"
    
    if gitleaks detect --no-git -v 2>&1 | grep -q "leaks found"; then
        LEAKS_COUNT=$(gitleaks detect --no-git -v 2>&1 | grep -o "[0-9]* leaks found" | awk '{print $1}')
        report_finding "CRITICAL" "Found $LEAKS_COUNT potential secrets in files"
    else
        report_finding "PASS" "No secrets detected in files"
    fi
else
    # Manual basic secret scanning
    echo -e "${YELLOW}Performing basic secret scan...${NC}"
    
    # Check for common patterns
    if grep -r -E "(password|passwd|pwd|secret|token|api[_-]?key).*=.*['\"][^'\"]{8,}['\"]" . \
        --include="*.yml" --include="*.yaml" --include="*.conf" --include="*.config" \
        --exclude-dir=".git" --exclude-dir="node_modules" 2>/dev/null | grep -v ".example" | grep -q .; then
        report_finding "HIGH" "Potential secrets found in configuration files"
    else
        report_finding "PASS" "No obvious secrets found in configuration files"
    fi
fi

# 4. Docker Container Security
echo -e "\n${BLUE}=== Docker Container Security ===${NC}"

# Check if containers are running as root
RUNNING_CONTAINERS=$(docker ps --format '{{.Names}}' | grep "^horizen-" || echo "")

if [ -n "$RUNNING_CONTAINERS" ]; then
    for container in $RUNNING_CONTAINERS; do
        USER_ID=$(docker exec "$container" id -u 2>/dev/null || echo "unknown")
        if [ "$USER_ID" = "0" ]; then
            report_finding "MEDIUM" "Container $container is running as root"
        elif [ "$USER_ID" != "unknown" ]; then
            report_finding "PASS" "Container $container is running as non-root user (UID: $USER_ID)"
        fi
    done
else
    report_finding "INFO" "No running containers to check"
fi

# Check for privileged containers
if docker ps --format '{{.Names}}: {{.Status}}' | grep -i "privileged" | grep -q "^horizen-"; then
    report_finding "HIGH" "Some containers are running in privileged mode"
else
    report_finding "PASS" "No containers running in privileged mode"
fi

# 5. Network Security
echo -e "\n${BLUE}=== Network Security ===${NC}"

# Check if database ports are exposed
if [ "${ENVIRONMENT}" = "production" ]; then
    if docker ps | grep "horizen-postgres" | grep -q "0.0.0.0:5432"; then
        report_finding "HIGH" "PostgreSQL port is exposed to all interfaces in production"
    fi
    
    if docker ps | grep "horizen-mongodb" | grep -q "0.0.0.0:27017"; then
        report_finding "HIGH" "MongoDB port is exposed to all interfaces in production"
    fi
    
    if docker ps | grep "horizen-redis" | grep -q "0.0.0.0:6379"; then
        report_finding "HIGH" "Redis port is exposed to all interfaces in production"
    fi
fi

# Check firewall status
if command -v ufw >/dev/null 2>&1; then
    if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        report_finding "PASS" "UFW firewall is active"
    else
        report_finding "MEDIUM" "UFW firewall is not active"
    fi
else
    report_finding "INFO" "UFW not installed"
fi

# 6. File Permission Checks
echo -e "\n${BLUE}=== File Permission Checks ===${NC}"

# Check script permissions
for script in scripts/*.sh; do
    if [ -f "$script" ]; then
        PERMS=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%OLp" "$script" 2>/dev/null || echo "000")
        if [ "${PERMS:0:1}" -gt 7 ] || [ "${PERMS:1:1}" -gt 5 ] || [ "${PERMS:2:1}" -gt 5 ]; then
            report_finding "MEDIUM" "$script has overly permissive permissions ($PERMS)"
        fi
    fi
done

# Check for world-writable files
WORLD_WRITABLE=$(find . -type f -perm -002 ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./backups/*" 2>/dev/null || echo "")
if [ -n "$WORLD_WRITABLE" ]; then
    report_finding "MEDIUM" "World-writable files found"
else
    report_finding "PASS" "No world-writable files found"
fi

# 7. SSL/TLS Certificate Checks
echo -e "\n${BLUE}=== SSL/TLS Certificate Checks ===${NC}"

if [ "${ENABLE_SSL}" = "true" ] && [ -n "${DOMAIN}" ]; then
    if [ -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
        CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
        if [ -f "$CERT_FILE" ]; then
            # Check certificate expiration
            EXPIRY_DATE=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)
            EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
            CURRENT_EPOCH=$(date +%s)
            DAYS_UNTIL_EXPIRY=$(( ($EXPIRY_EPOCH - $CURRENT_EPOCH) / 86400 ))
            
            if [ $DAYS_UNTIL_EXPIRY -lt 7 ]; then
                report_finding "CRITICAL" "SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
            elif [ $DAYS_UNTIL_EXPIRY -lt 30 ]; then
                report_finding "HIGH" "SSL certificate expires in $DAYS_UNTIL_EXPIRY days"
            else
                report_finding "PASS" "SSL certificate is valid for $DAYS_UNTIL_EXPIRY more days"
            fi
            
            # Check certificate strength
            KEY_SIZE=$(openssl x509 -in "$CERT_FILE" -noout -text 2>/dev/null | grep "Public-Key:" | grep -o "[0-9]*")
            if [ "$KEY_SIZE" -lt 2048 ]; then
                report_finding "HIGH" "SSL certificate key size is less than 2048 bits ($KEY_SIZE bits)"
            fi
        fi
    else
        report_finding "MEDIUM" "SSL is enabled but certificate not found"
    fi
fi

# 8. Compliance Checks
echo -e "\n${BLUE}=== Compliance Checks ===${NC}"

# Check for security headers in Nginx
if [ -f nginx/nginx.conf ] || [ -f nginx/conf.d/default.conf ]; then
    NGINX_CONF=$(cat nginx/nginx.conf nginx/conf.d/*.conf 2>/dev/null || echo "")
    
    if echo "$NGINX_CONF" | grep -q "X-Frame-Options"; then
        report_finding "PASS" "X-Frame-Options header configured"
    else
        report_finding "MEDIUM" "X-Frame-Options header not configured"
    fi
    
    if echo "$NGINX_CONF" | grep -q "X-Content-Type-Options"; then
        report_finding "PASS" "X-Content-Type-Options header configured"
    else
        report_finding "MEDIUM" "X-Content-Type-Options header not configured"
    fi
    
    if echo "$NGINX_CONF" | grep -q "Content-Security-Policy"; then
        report_finding "PASS" "Content-Security-Policy header configured"
    else
        report_finding "LOW" "Content-Security-Policy header not configured"
    fi
fi

# Check backup encryption
if [ -d backups ]; then
    if ls backups/*.gpg >/dev/null 2>&1; then
        report_finding "PASS" "Encrypted backups found"
    else
        if ls backups/*.tar.gz >/dev/null 2>&1 || ls backups/*.sql >/dev/null 2>&1; then
            report_finding "MEDIUM" "Unencrypted backups found"
        fi
    fi
fi

# 9. Dependency Vulnerability Check
echo -e "\n${BLUE}=== Dependency Vulnerability Check ===${NC}"

# Check for outdated Docker images
if command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}Checking for outdated images...${NC}"
    
    OUTDATED=0
    while IFS= read -r image; do
        if docker pull "$image" 2>&1 | grep -q "Image is up to date"; then
            :  # Image is up to date
        else
            report_finding "INFO" "Update available for image: $image"
            ((OUTDATED++))
        fi
    done < <(docker-compose config 2>/dev/null | grep "image:" | awk '{print $2}' | sort | uniq)
    
    if [ $OUTDATED -gt 0 ]; then
        report_finding "LOW" "$OUTDATED Docker images have updates available"
    fi
fi

# Summary
echo -e "\n${BLUE}=== Security Scan Summary ===${NC}"
echo -e "${RED}Critical: $CRITICAL${NC}"
echo -e "${RED}High: $HIGH${NC}"
echo -e "${YELLOW}Medium: $MEDIUM${NC}"
echo -e "${YELLOW}Low: $LOW${NC}"
echo -e "${BLUE}Info: $INFO${NC}"

TOTAL_ISSUES=$((CRITICAL + HIGH + MEDIUM + LOW))
echo -e "\nTotal Issues: $TOTAL_ISSUES"

# Exit code based on findings
if [ $CRITICAL -gt 0 ]; then
    echo -e "\n${RED}✗ Critical security issues found!${NC}"
    echo -e "${RED}  Please address critical issues before deployment${NC}"
    exit 2
elif [ $HIGH -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ High severity security issues found${NC}"
    echo -e "${YELLOW}  Recommend addressing before production deployment${NC}"
    exit 1
elif [ $TOTAL_ISSUES -gt 0 ]; then
    echo -e "\n${GREEN}✓ No critical or high severity issues found${NC}"
    echo -e "${YELLOW}  Some medium/low severity issues to address${NC}"
    exit 0
else
    echo -e "\n${GREEN}✓ No security issues found!${NC}"
    exit 0
fi
