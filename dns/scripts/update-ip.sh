#!/bin/bash

# Update DNS A Record with New IP Address
# Useful for server migration or dynamic IPs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NEW_IP="$1"
PROVIDER="${2:-manual}"

if [ -z "$NEW_IP" ]; then
    echo -e "${RED}Error: No IP address provided${NC}"
    echo "Usage: $0 <new_ip_address> [provider]"
    echo "Example: $0 203.0.113.10 cloudflare"
    exit 1
fi

# Validate IP format
if ! echo "$NEW_IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo -e "${RED}Error: Invalid IP address format${NC}"
    exit 1
fi

DOMAIN="${DOMAIN:-horizen-network.com}"

echo -e "${YELLOW}Updating DNS A record for ${DOMAIN}${NC}"
echo -e "New IP: ${NEW_IP}"
echo -e "Provider: ${PROVIDER}\n"

case "$PROVIDER" in
    cloudflare)
        if [ -z "$CLOUDFLARE_API_TOKEN" ] || [ -z "$CLOUDFLARE_ZONE_ID" ]; then
            echo -e "${RED}Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ZONE_ID required${NC}"
            exit 1
        fi
        
        export SERVER_IP="$NEW_IP"
        ./dns/scripts/setup-cloudflare.sh
        ;;
    
    manual)
        echo -e "${YELLOW}Manual update required:${NC}"
        echo -e "1. Log in to your DNS provider"
        echo -e "2. Find the A record for ${DOMAIN}"
        echo -e "3. Update the IP address to: ${NEW_IP}"
        echo -e "4. Save changes"
        echo -e "5. Wait for DNS propagation (5-60 minutes)"
        echo -e "6. Verify: dig ${DOMAIN} A +short"
        ;;
    
    *)
        echo -e "${RED}Error: Unknown provider: ${PROVIDER}${NC}"
        echo "Supported providers: cloudflare, manual"
        exit 1
        ;;
esac

echo -e "\n${GREEN}✓ IP update process initiated${NC}"
echo -e "Verify with: ./dns/scripts/verify-dns.sh"
