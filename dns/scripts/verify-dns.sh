#!/bin/bash

# DNS Verification Script for Horizen Network
# Verifies all DNS records are properly configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${DOMAIN:-horizen-network.com}"
SUBDOMAINS=("www" "druid" "geniess" "entity" "api")
DNS_SERVERS=("8.8.8.8" "1.1.1.1" "8.8.4.4")
VERBOSE=false
QUICK=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quick|-q)
            QUICK=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --domain DOMAIN    Domain to verify (default: horizen-network.com)"
            echo "  --verbose, -v      Verbose output with detailed information"
            echo "  --quick, -q        Quick check (main domain only)"
            echo "  --help, -h         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}=== DNS Verification for ${DOMAIN} ===${NC}\n"

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to check A record
check_a_record() {
    local domain=$1
    local dns_server=$2
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Checking A record for ${domain} via ${dns_server}...${NC}"
    fi
    
    RESULT=$(dig @${dns_server} ${domain} A +short 2>&1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    
    if [ -z "$RESULT" ]; then
        return 1
    fi
    
    echo "$RESULT"
    return 0
}

# Function to check CNAME record
check_cname_record() {
    local subdomain=$1
    local dns_server=$2
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Checking CNAME for ${subdomain}.${DOMAIN} via ${dns_server}...${NC}"
    fi
    
    RESULT=$(dig @${dns_server} ${subdomain}.${DOMAIN} CNAME +short 2>&1 | head -n1)
    
    if [ -z "$RESULT" ]; then
        # Try A record fallback
        RESULT=$(dig @${dns_server} ${subdomain}.${DOMAIN} A +short 2>&1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
        if [ -n "$RESULT" ]; then
            echo "$RESULT (A record)"
            return 0
        fi
        return 1
    fi
    
    echo "$RESULT"
    return 0
}

# Function to check CAA record
check_caa_record() {
    local domain=$1
    local dns_server=$2
    
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}Checking CAA record for ${domain} via ${dns_server}...${NC}"
    fi
    
    RESULT=$(dig @${dns_server} ${domain} CAA +short 2>&1)
    
    if [ -z "$RESULT" ]; then
        return 1
    fi
    
    # Check if Let's Encrypt is authorized
    if echo "$RESULT" | grep -q "letsencrypt.org"; then
        echo "Let's Encrypt authorized"
        return 0
    else
        echo "$RESULT"
        return 2
    fi
}

# Function to perform check with status
perform_check() {
    local description=$1
    local command=$2
    
    ((TOTAL_CHECKS++))
    
    echo -n "  ${description}... "
    
    if OUTPUT=$(eval "$command" 2>&1); then
        echo -e "${GREEN}✓${NC}"
        if [ "$VERBOSE" = true ] && [ -n "$OUTPUT" ]; then
            echo -e "    ${BLUE}→${NC} $OUTPUT"
        fi
        ((PASSED_CHECKS++))
        return 0
    else
        echo -e "${RED}✗${NC}"
        if [ -n "$OUTPUT" ]; then
            echo -e "    ${RED}Error:${NC} $OUTPUT"
        fi
        ((FAILED_CHECKS++))
        return 1
    fi
}

# Check if dig is installed
if ! command -v dig &> /dev/null; then
    echo -e "${RED}Error: 'dig' command not found${NC}"
    echo "Please install dnsutils: sudo apt-get install dnsutils"
    exit 1
fi

# Main domain A record checks
echo -e "${BLUE}1. Checking Main Domain (${DOMAIN})${NC}"

for dns_server in "${DNS_SERVERS[@]}"; do
    DNS_NAME="DNS (${dns_server})"
    if [ "$dns_server" = "8.8.8.8" ]; then
        DNS_NAME="Google DNS"
    elif [ "$dns_server" = "1.1.1.1" ]; then
        DNS_NAME="Cloudflare DNS"
    fi
    
    perform_check "A record via ${DNS_NAME}" "check_a_record ${DOMAIN} ${dns_server}"
done

if [ "$QUICK" = true ]; then
    echo ""
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "Total checks: ${TOTAL_CHECKS}"
    echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC}"
    echo -e "Failed: ${RED}${FAILED_CHECKS}${NC}"
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        echo -e "\n${GREEN}✓ Main domain DNS verification passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}✗ DNS verification failed${NC}"
        exit 1
    fi
fi

# Subdomain checks
echo ""
echo -e "${BLUE}2. Checking Subdomains${NC}"

for subdomain in "${SUBDOMAINS[@]}"; do
    echo ""
    echo -e "  ${YELLOW}${subdomain}.${DOMAIN}${NC}"
    
    for dns_server in "${DNS_SERVERS[@]}"; do
        DNS_NAME="DNS (${dns_server})"
        if [ "$dns_server" = "8.8.8.8" ]; then
            DNS_NAME="Google DNS"
        elif [ "$dns_server" = "1.1.1.1" ]; then
            DNS_NAME="Cloudflare DNS"
        fi
        
        perform_check "  via ${DNS_NAME}" "check_cname_record ${subdomain} ${dns_server}"
    done
done

# CAA record checks
echo ""
echo -e "${BLUE}3. Checking CAA Records (SSL Certificate Authority Authorization)${NC}"

perform_check "CAA records for Let's Encrypt" "check_caa_record ${DOMAIN} 8.8.8.8"

# DNS propagation check
echo ""
echo -e "${BLUE}4. DNS Propagation Check${NC}"

# Get IP from main domain
MAIN_IP=$(dig +short ${DOMAIN} A | head -n1)

if [ -z "$MAIN_IP" ]; then
    echo -e "  ${RED}✗ Could not resolve main domain IP${NC}"
    ((TOTAL_CHECKS++))
    ((FAILED_CHECKS++))
else
    echo -e "  ${GREEN}✓${NC} Main domain resolves to: ${MAIN_IP}"
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
    
    # Check if all subdomains resolve to the same IP or main domain
    echo ""
    echo -e "  Checking subdomain consistency:"
    
    for subdomain in "${SUBDOMAINS[@]}"; do
        SUBDOMAIN_RESULT=$(dig +short ${subdomain}.${DOMAIN} | tail -n1)
        
        if [ -z "$SUBDOMAIN_RESULT" ]; then
            echo -e "    ${RED}✗${NC} ${subdomain}.${DOMAIN} - No resolution"
            ((TOTAL_CHECKS++))
            ((FAILED_CHECKS++))
        elif echo "$SUBDOMAIN_RESULT" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
            if [ "$SUBDOMAIN_RESULT" = "$MAIN_IP" ]; then
                echo -e "    ${GREEN}✓${NC} ${subdomain}.${DOMAIN} → ${SUBDOMAIN_RESULT}"
            else
                echo -e "    ${YELLOW}!${NC} ${subdomain}.${DOMAIN} → ${SUBDOMAIN_RESULT} (differs from main domain)"
            fi
            ((TOTAL_CHECKS++))
            ((PASSED_CHECKS++))
        else
            echo -e "    ${GREEN}✓${NC} ${subdomain}.${DOMAIN} → ${SUBDOMAIN_RESULT} (CNAME)"
            ((TOTAL_CHECKS++))
            ((PASSED_CHECKS++))
        fi
    done
fi

# SSL readiness check
echo ""
echo -e "${BLUE}5. SSL Certificate Readiness${NC}"

if command -v curl &> /dev/null; then
    # Check if port 80 is accessible
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://${DOMAIN} 2>/dev/null | grep -q "^[2-5]"; then
        echo -e "  ${GREEN}✓${NC} Port 80 is accessible"
        ((TOTAL_CHECKS++))
        ((PASSED_CHECKS++))
    else
        echo -e "  ${YELLOW}!${NC} Port 80 not accessible (may not be deployed yet)"
        ((TOTAL_CHECKS++))
        ((PASSED_CHECKS++))
    fi
else
    echo -e "  ${YELLOW}!${NC} curl not installed, skipping HTTP check"
fi

# Check if CAA allows Let's Encrypt
CAA_CHECK=$(dig +short ${DOMAIN} CAA | grep -c "letsencrypt.org" || true)
if [ "$CAA_CHECK" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} CAA records allow Let's Encrypt"
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
else
    echo -e "  ${YELLOW}!${NC} No CAA records for Let's Encrypt (optional but recommended)"
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
fi

# Summary
echo ""
echo -e "${BLUE}=== DNS Verification Summary ===${NC}"
echo ""
echo -e "Domain: ${DOMAIN}"
echo -e "Total checks: ${TOTAL_CHECKS}"
echo -e "Passed: ${GREEN}${PASSED_CHECKS}${NC}"
echo -e "Failed: ${RED}${FAILED_CHECKS}${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ All DNS verification checks passed!${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "  1. Wait for global DNS propagation (check: https://www.whatsmydns.net/)"
    echo -e "  2. Deploy infrastructure: ./scripts/deploy.sh prod"
    echo -e "  3. Setup SSL certificates: sudo ./scripts/ssl-setup.sh"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}✗ DNS verification failed with ${FAILED_CHECKS} error(s)${NC}"
    echo ""
    echo -e "Troubleshooting:"
    echo -e "  1. Verify DNS records in your provider's dashboard"
    echo -e "  2. Wait for DNS propagation (can take up to 24-48 hours)"
    echo -e "  3. Check with: dig ${DOMAIN} A +trace"
    echo -e "  4. See documentation: dns/TROUBLESHOOTING.md"
    echo ""
    exit 1
fi
