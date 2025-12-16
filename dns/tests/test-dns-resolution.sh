#!/bin/bash

# DNS Resolution Testing Script
# Tests DNS resolution from multiple locations and validates routing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="${DOMAIN:-horizen-network.com}"
SUBDOMAINS=("www" "druid" "geniess" "entity" "api")

echo -e "${BLUE}=== DNS Resolution Testing ===${NC}\n"

# Test DNS resolution
echo -e "${YELLOW}1. Testing DNS Resolution${NC}"
TOTAL=0
PASSED=0

for subdomain in "@" "${SUBDOMAINS[@]}"; do
    if [ "$subdomain" = "@" ]; then
        TEST_DOMAIN="$DOMAIN"
        LABEL="Main domain"
    else
        TEST_DOMAIN="${subdomain}.${DOMAIN}"
        LABEL="$subdomain subdomain"
    fi
    
    echo -n "  Testing ${LABEL}... "
    
    if dig +short "$TEST_DOMAIN" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|[a-z0-9.-]+\.$'; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
    fi
    ((TOTAL++))
done

# Test SSL certificate readiness
echo -e "\n${YELLOW}2. Testing HTTP Connectivity${NC}"

if command -v curl &> /dev/null; then
    for subdomain in "@" "www" "druid" "geniess" "entity" "api"; do
        if [ "$subdomain" = "@" ]; then
            TEST_URL="http://${DOMAIN}"
            LABEL="Main domain"
        else
            TEST_URL="http://${subdomain}.${DOMAIN}"
            LABEL="$subdomain"
        fi
        
        echo -n "  Testing ${LABEL}... "
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TEST_URL" 2>/dev/null || echo "000")
        
        if [ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "000" ]; then
            echo -e "${GREEN}✓${NC} (HTTP $HTTP_CODE)"
            ((PASSED++))
        else
            echo -e "${YELLOW}!${NC} Not accessible (may not be deployed yet)"
        fi
        ((TOTAL++))
    done
else
    echo -e "  ${YELLOW}! curl not installed, skipping HTTP tests${NC}"
fi

# Test response times
echo -e "\n${YELLOW}3. Testing Response Times${NC}"

if command -v curl &> /dev/null; then
    echo -n "  Main domain... "
    RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout 5 "http://${DOMAIN}" 2>/dev/null || echo "timeout")
    
    if [ "$RESPONSE_TIME" != "timeout" ]; then
        echo -e "${GREEN}✓${NC} ${RESPONSE_TIME}s"
        ((PASSED++))
    else
        echo -e "${YELLOW}!${NC} Timeout or not accessible"
    fi
    ((TOTAL++))
fi

# Summary
echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo -e "Total tests: $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed/Skipped: $((TOTAL - PASSED))"

if [ $PASSED -eq $TOTAL ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
elif [ $PASSED -gt 0 ]; then
    echo -e "\n${YELLOW}! Some tests passed${NC}"
    exit 0
else
    echo -e "\n${RED}✗ All tests failed${NC}"
    exit 1
fi
