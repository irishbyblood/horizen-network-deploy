#!/bin/bash

# Cloudflare DNS Setup Automation Script
# Automates DNS configuration using Cloudflare API

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Cloudflare DNS Setup Automation ===${NC}\n"

# Check required environment variables
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${RED}Error: CLOUDFLARE_API_TOKEN environment variable not set${NC}"
    echo "Get your API token from: https://dash.cloudflare.com/profile/api-tokens"
    exit 1
fi

if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo -e "${RED}Error: CLOUDFLARE_ZONE_ID environment variable not set${NC}"
    echo "Find your Zone ID in the Cloudflare dashboard under your domain"
    exit 1
fi

if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Error: SERVER_IP environment variable not set${NC}"
    echo "Set your server's public IP address"
    exit 1
fi

# Validate IP address format
if ! echo "$SERVER_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo -e "${RED}Error: Invalid IP address format: $SERVER_IP${NC}"
    exit 1
fi

# Validate each octet is 0-255
IFS='.' read -ra OCTETS <<< "$SERVER_IP"
for octet in "${OCTETS[@]}"; do
    if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
        echo -e "${RED}Error: Invalid IP address - octet out of range (0-255): $SERVER_IP${NC}"
        exit 1
    fi
done

# Configuration
DOMAIN="${DOMAIN:-horizen-network.com}"
API_URL="https://api.cloudflare.com/client/v4"
SUBDOMAINS=("www" "druid" "geniess" "entity" "api")

echo -e "Configuration:"
echo -e "  Domain: ${DOMAIN}"
echo -e "  Server IP: ${SERVER_IP}"
echo -e "  Zone ID: ${CLOUDFLARE_ZONE_ID:0:10}...${NC}\n"

# Function to make Cloudflare API request
cf_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ -z "$data" ]; then
        curl -s -X ${method} \
            "${API_URL}${endpoint}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json"
    else
        curl -s -X ${method} \
            "${API_URL}${endpoint}" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "${data}"
    fi
}

# Function to check API response for errors
check_response() {
    local response=$1
    local action=$2
    
    if echo "$response" | jq -e '.success == false' > /dev/null 2>&1; then
        echo -e "${RED}✗ Failed to ${action}${NC}"
        echo "$response" | jq -r '.errors[] | "  Error: \(.message)"'
        return 1
    fi
    return 0
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq not installed. Installing...${NC}"
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y jq -qq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq -q
    else
        echo -e "${RED}Error: Cannot install jq automatically. Please install it manually.${NC}"
        exit 1
    fi
fi

# Verify API token and zone ID
echo -e "${YELLOW}1. Verifying Cloudflare credentials...${NC}"
VERIFY_RESPONSE=$(cf_api GET "/zones/${CLOUDFLARE_ZONE_ID}")

if check_response "$VERIFY_RESPONSE" "verify credentials"; then
    ZONE_NAME=$(echo "$VERIFY_RESPONSE" | jq -r '.result.name')
    echo -e "${GREEN}✓ Successfully connected to Cloudflare${NC}"
    echo -e "  Zone: ${ZONE_NAME}"
    
    if [ "$ZONE_NAME" != "$DOMAIN" ]; then
        echo -e "${YELLOW}! Warning: Zone name (${ZONE_NAME}) differs from expected domain (${DOMAIN})${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo -e "${RED}✗ Failed to verify Cloudflare credentials${NC}"
    exit 1
fi

# Get existing DNS records
echo -e "\n${YELLOW}2. Checking existing DNS records...${NC}"
EXISTING_RECORDS=$(cf_api GET "/zones/${CLOUDFLARE_ZONE_ID}/dns_records")

# Function to check if record exists
record_exists() {
    local name=$1
    local type=$2
    echo "$EXISTING_RECORDS" | jq -e ".result[] | select(.name == \"${name}\" and .type == \"${type}\")" > /dev/null 2>&1
}

# Function to get record ID
get_record_id() {
    local name=$1
    local type=$2
    echo "$EXISTING_RECORDS" | jq -r ".result[] | select(.name == \"${name}\" and .type == \"${type}\") | .id"
}

# Create or update A record for main domain
echo -e "\n${YELLOW}3. Creating/updating A record for main domain...${NC}"

A_RECORD_DATA=$(cat <<EOF
{
  "type": "A",
  "name": "@",
  "content": "${SERVER_IP}",
  "ttl": 1,
  "proxied": false
}
EOF
)

if record_exists "${DOMAIN}" "A"; then
    RECORD_ID=$(get_record_id "${DOMAIN}" "A")
    echo -e "  Updating existing A record..."
    RESPONSE=$(cf_api PUT "/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" "$A_RECORD_DATA")
    if check_response "$RESPONSE" "update A record"; then
        echo -e "${GREEN}✓ A record updated${NC}"
    fi
else
    echo -e "  Creating new A record..."
    RESPONSE=$(cf_api POST "/zones/${CLOUDFLARE_ZONE_ID}/dns_records" "$A_RECORD_DATA")
    if check_response "$RESPONSE" "create A record"; then
        echo -e "${GREEN}✓ A record created${NC}"
    fi
fi

# Create or update CNAME records for subdomains
echo -e "\n${YELLOW}4. Creating/updating CNAME records for subdomains...${NC}"

for subdomain in "${SUBDOMAINS[@]}"; do
    FULL_SUBDOMAIN="${subdomain}.${DOMAIN}"
    
    # Set proxy status based on subdomain
    PROXIED="false"
    if [ "$subdomain" = "www" ]; then
        PROXIED="true"
    fi
    
    CNAME_DATA=$(cat <<EOF
{
  "type": "CNAME",
  "name": "${subdomain}",
  "content": "${DOMAIN}",
  "ttl": 1,
  "proxied": ${PROXIED}
}
EOF
)
    
    echo -e "  Processing ${subdomain}..."
    
    if record_exists "${FULL_SUBDOMAIN}" "CNAME"; then
        RECORD_ID=$(get_record_id "${FULL_SUBDOMAIN}" "CNAME")
        RESPONSE=$(cf_api PUT "/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" "$CNAME_DATA")
        if check_response "$RESPONSE" "update CNAME for ${subdomain}"; then
            echo -e "    ${GREEN}✓${NC} Updated CNAME: ${subdomain}"
        fi
    else
        RESPONSE=$(cf_api POST "/zones/${CLOUDFLARE_ZONE_ID}/dns_records" "$CNAME_DATA")
        if check_response "$RESPONSE" "create CNAME for ${subdomain}"; then
            echo -e "    ${GREEN}✓${NC} Created CNAME: ${subdomain}"
        fi
    fi
done

# Create CAA records for Let's Encrypt
echo -e "\n${YELLOW}5. Creating CAA records for SSL certificates...${NC}"

CAA_RECORDS=(
    "0 issue \"letsencrypt.org\""
    "0 issuewild \"letsencrypt.org\""
)

for caa_value in "${CAA_RECORDS[@]}"; do
    CAA_DATA=$(cat <<EOF
{
  "type": "CAA",
  "name": "@",
  "data": {
    "flags": 0,
    "tag": "$(echo $caa_value | awk '{print $2}' | tr -d '\"')",
    "value": "letsencrypt.org"
  },
  "ttl": 1
}
EOF
)
    
    TAG=$(echo $caa_value | awk '{print $2}' | tr -d '"')
    echo -e "  Processing CAA ${TAG}..."
    
    # Check if this specific CAA record exists
    CAA_EXISTS=$(echo "$EXISTING_RECORDS" | jq -e ".result[] | select(.type == \"CAA\" and .data.tag == \"${TAG}\")" > /dev/null 2>&1 && echo "true" || echo "false")
    
    if [ "$CAA_EXISTS" = "true" ]; then
        echo -e "    ${GREEN}✓${NC} CAA ${TAG} record already exists"
    else
        RESPONSE=$(cf_api POST "/zones/${CLOUDFLARE_ZONE_ID}/dns_records" "$CAA_DATA")
        if check_response "$RESPONSE" "create CAA ${TAG} record"; then
            echo -e "    ${GREEN}✓${NC} Created CAA ${TAG} record"
        fi
    fi
done

# Summary
echo -e "\n${BLUE}=== Setup Complete ===${NC}\n"
echo -e "${GREEN}✓ DNS records have been configured successfully!${NC}\n"
echo -e "Summary:"
echo -e "  • A record: ${DOMAIN} → ${SERVER_IP}"
echo -e "  • CNAME records created for: ${SUBDOMAINS[*]}"
echo -e "  • CAA records configured for Let's Encrypt"
echo -e "\nNext steps:"
echo -e "  1. Wait 5-10 minutes for DNS propagation"
echo -e "  2. Verify DNS: ./dns/scripts/verify-dns.sh"
echo -e "  3. Deploy infrastructure: ./scripts/deploy.sh prod"
echo -e "  4. Setup SSL: sudo ./scripts/ssl-setup.sh"
echo -e "\nCheck DNS propagation: https://www.whatsmydns.net/?t=A&q=${DOMAIN}"
