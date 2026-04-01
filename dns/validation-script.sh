#!/bin/bash

# DNS Validation Script for Horizen Network
# Verifies DNS propagation for all required domains

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Horizen Network DNS Validation ===${NC}\n"

# Domain configuration
DOMAIN="horizen-network.com"
SUBDOMAINS=("www" "druid" "geniess" "entity")

# DNS servers to check
DNS_SERVERS=(
    "8.8.8.8:Google"
    "1.1.1.1:Cloudflare"
    "9.9.9.9:Quad9"
)

ERRORS=0
WARNINGS=0
CHECKS=0

# Function to check A record
check_a_record() {
    local domain=$1
    local expected_ip=$2
    
    ((CHECKS++))
    echo -e "${YELLOW}Checking A record for: ${domain}${NC}"
    
    if command -v dig &> /dev/null; then
        result=$(dig +short "$domain" A | head -1)
    elif command -v nslookup &> /dev/null; then
        result=$(nslookup "$domain" | grep "Address:" | tail -1 | awk '{print $2}')
    else
        echo -e "${RED}✗ Neither dig nor nslookup available${NC}"
        ((ERRORS++))
        return
    fi
    
    if [ -z "$result" ]; then
        echo -e "${RED}✗ No A record found for $domain${NC}"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ $domain resolves to: $result${NC}"
        
        if [ -n "$expected_ip" ] && [ "$result" != "$expected_ip" ]; then
            echo -e "${YELLOW}! IP mismatch: expected $expected_ip, got $result${NC}"
            ((WARNINGS++))
        fi
    fi
    echo ""
}

# Function to check CNAME record
check_cname_record() {
    local domain=$1
    local expected_target=$2
    
    ((CHECKS++))
    echo -e "${YELLOW}Checking CNAME record for: ${domain}${NC}"
    
    if command -v dig &> /dev/null; then
        result=$(dig +short "$domain" CNAME | head -1)
    elif command -v nslookup &> /dev/null; then
        result=$(nslookup -query=CNAME "$domain" | grep "canonical name" | awk '{print $NF}')
    else
        echo -e "${RED}✗ Neither dig nor nslookup available${NC}"
        ((ERRORS++))
        return
    fi
    
    if [ -z "$result" ]; then
        # CNAME might be missing, check if A record exists
        check_a_record "$domain" ""
        echo -e "${YELLOW}! No CNAME record found (may be using A record instead)${NC}"
        ((WARNINGS++))
    else
        # Remove trailing dot
        result=${result%.}
        echo -e "${GREEN}✓ $domain CNAME points to: $result${NC}"
        
        if [ -n "$expected_target" ] && [ "$result" != "$expected_target" ]; then
            echo -e "${YELLOW}! CNAME mismatch: expected $expected_target, got $result${NC}"
            ((WARNINGS++))
        fi
    fi
    echo ""
}

# Function to check DNS from multiple servers
check_dns_propagation() {
    local domain=$1
    
    echo -e "${BLUE}Checking DNS propagation for $domain across multiple servers:${NC}"
    
    for server_info in "${DNS_SERVERS[@]}"; do
        IFS=':' read -r server name <<< "$server_info"
        
        if command -v dig &> /dev/null; then
            result=$(dig @"$server" +short "$domain" A | head -1)
            if [ -n "$result" ]; then
                echo -e "  ${GREEN}✓ $name ($server): $result${NC}"
            else
                echo -e "  ${RED}✗ $name ($server): No response${NC}"
                ((ERRORS++))
            fi
        fi
    done
    echo ""
}

# Get expected IP (if server is running locally)
EXPECTED_IP=""
if command -v curl &> /dev/null; then
    EXPECTED_IP=$(curl -s -4 ifconfig.me 2>/dev/null || echo "")
    if [ -n "$EXPECTED_IP" ]; then
        echo -e "${BLUE}Detected server IP: $EXPECTED_IP${NC}\n"
    fi
fi

# Check main domain
echo -e "${BLUE}=== Checking Main Domain ===${NC}"
check_a_record "$DOMAIN" "$EXPECTED_IP"
check_dns_propagation "$DOMAIN"

# Check WWW subdomain (IMPORTANT)
echo -e "${BLUE}=== Checking WWW Subdomain (REQUIRED) ===${NC}"
check_cname_record "www.$DOMAIN" "$DOMAIN"
check_dns_propagation "www.$DOMAIN"

# Check other subdomains
echo -e "${BLUE}=== Checking Service Subdomains ===${NC}"
for subdomain in "${SUBDOMAINS[@]}"; do
    if [ "$subdomain" != "www" ]; then
        check_a_record "$subdomain.$DOMAIN" "$EXPECTED_IP"
    fi
done

# Check reverse DNS (optional)
if [ -n "$EXPECTED_IP" ]; then
    echo -e "${BLUE}=== Checking Reverse DNS ===${NC}"
    ((CHECKS++))
    if command -v dig &> /dev/null; then
        reverse=$(dig +short -x "$EXPECTED_IP" | head -1)
        if [ -n "$reverse" ]; then
            echo -e "${GREEN}✓ Reverse DNS for $EXPECTED_IP: $reverse${NC}"
        else
            echo -e "${YELLOW}! No reverse DNS configured${NC}"
            ((WARNINGS++))
        fi
    fi
    echo ""
fi

# Check SSL readiness
echo -e "${BLUE}=== Checking SSL/HTTP Access ===${NC}"
for test_domain in "$DOMAIN" "www.$DOMAIN" "druid.$DOMAIN"; do
    ((CHECKS++))
    if command -v curl &> /dev/null; then
        if curl -s -I -m 5 "http://$test_domain" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ HTTP accessible: $test_domain${NC}"
        else
            echo -e "${YELLOW}! HTTP not accessible: $test_domain${NC}"
            ((WARNINGS++))
        fi
    fi
done
echo ""

# Summary
echo -e "${GREEN}=== Validation Summary ===${NC}"
echo -e "Total checks: $CHECKS"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "\n${GREEN}✓ All DNS records are properly configured!${NC}"
    echo -e "${GREEN}✓ www.horizen-network.com is correctly configured${NC}"
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "1. Run SSL setup: ${YELLOW}sudo ./scripts/ssl-setup.sh${NC}"
    echo -e "2. Deploy services: ${YELLOW}./scripts/production-deploy.sh${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "\n${YELLOW}DNS validation completed with warnings.${NC}"
    echo -e "${YELLOW}Review warnings above. System should still work.${NC}"
    exit 0
else
    echo -e "\n${RED}DNS validation failed with $ERRORS error(s).${NC}"
    echo -e "${RED}Please fix DNS configuration before deploying.${NC}"
    echo -e "\n${BLUE}Common issues:${NC}"
    echo -e "1. DNS not propagated yet (wait 5-60 minutes)"
    echo -e "2. Wrong IP address in DNS records"
    echo -e "3. Missing www CNAME record"
    echo -e "4. Typo in subdomain names"
    echo -e "\n${BLUE}Helpful commands:${NC}"
    echo -e "  dig horizen-network.com +short"
    echo -e "  dig www.horizen-network.com +short"
    echo -e "  nslookup www.horizen-network.com"
    echo -e "\n${BLUE}See detailed documentation:${NC}"
    echo -e "  docs/DNS_CONFIGURATION.md"
    exit 1
fi
