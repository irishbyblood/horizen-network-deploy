#!/bin/bash

# DNS Monitoring Script
# Continuously monitors DNS records and alerts on changes

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOMAIN="${DOMAIN:-horizen-network.com}"
INTERVAL="${INTERVAL:-300}"  # 5 minutes
EMAIL="${1}"

echo -e "${GREEN}=== DNS Monitoring for ${DOMAIN} ===${NC}"
echo -e "Checking every ${INTERVAL} seconds"
[ -n "$EMAIL" ] && echo -e "Alerts will be sent to: ${EMAIL}"
echo ""

# Store initial state
BASELINE_FILE="/tmp/dns_baseline_${DOMAIN}.txt"
dig +short ${DOMAIN} A > "$BASELINE_FILE"

send_alert() {
    local message=$1
    echo -e "${RED}ALERT: ${message}${NC}"
    
    if [ -n "$EMAIL" ] && command -v mail &> /dev/null; then
        echo "$message" | mail -s "DNS Alert for ${DOMAIN}" "$EMAIL"
    fi
}

check_dns() {
    local current=$(dig +short ${DOMAIN} A)
    local baseline=$(cat "$BASELINE_FILE")
    
    if [ "$current" != "$baseline" ]; then
        send_alert "DNS change detected! ${DOMAIN} changed from ${baseline} to ${current}"
        echo "$current" > "$BASELINE_FILE"
    else
        echo -e "${GREEN}✓${NC} $(date): DNS OK - ${current}"
    fi
}

# Monitor loop
while true; do
    check_dns
    sleep "$INTERVAL"
done
