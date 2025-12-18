#!/bin/bash

# SSL Certificate Setup Script using Let's Encrypt
# This script uses Certbot to obtain SSL certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SSL Certificate Setup ===${NC}"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}This script should be run as root or with sudo${NC}"
    exit 1
fi

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v certbot &> /dev/null; then
    echo -e "${YELLOW}Certbot not found. Installing...${NC}"
    
    # Detect OS and install certbot
    if [ -f /etc/debian_version ]; then
        apt-get update
        apt-get install -y certbot
    elif [ -f /etc/redhat-release ]; then
        yum install -y certbot
    else
        echo -e "${RED}Unsupported OS. Please install certbot manually${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Certbot installed${NC}"

# Validate required variables
if [ -z "$DOMAIN" ] || [ -z "$SSL_EMAIL" ]; then
    echo -e "${RED}Error: DOMAIN and SSL_EMAIL must be set in .env${NC}"
    exit 1
fi

# Verify DNS before requesting SSL certificates
echo -e "\n${YELLOW}Verifying DNS configuration before SSL setup...${NC}"
if [ -f dns/scripts/verify-dns.sh ]; then
    if ./dns/scripts/verify-dns.sh --quick; then
        echo -e "${GREEN}✓ DNS verification passed${NC}"
    else
        echo -e "${RED}✗ DNS verification failed${NC}"
        echo -e "${YELLOW}SSL certificates require proper DNS configuration${NC}"
        echo -e "Please ensure:"
        echo -e "  1. DNS A record points to this server"
        echo -e "  2. All subdomains resolve correctly"
        echo -e "  3. DNS has propagated globally"
        echo -e "\nRun: ./dns/scripts/verify-dns.sh for details"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ DNS verification script not found, skipping DNS check${NC}"
fi

# Create SSL directory
mkdir -p ssl

# Get certificates
echo -e "\n${YELLOW}Obtaining SSL certificates...${NC}"
echo -e "Domain: $DOMAIN"
echo -e "Subdomains: www.$DOMAIN, druid.$DOMAIN, geniess.$DOMAIN, entity.$DOMAIN, api.$DOMAIN"
echo -e "Email: $SSL_EMAIL"

# Stop nginx temporarily for standalone mode
if docker ps | grep -q horizen-nginx; then
    echo -e "${YELLOW}Stopping Nginx temporarily...${NC}"
    docker-compose stop nginx
    RESTART_NGINX=true
fi

# Obtain certificate using standalone mode
certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$SSL_EMAIL" \
    -d "$DOMAIN" \
    -d "www.$DOMAIN" \
    -d "druid.$DOMAIN" \
    -d "geniess.$DOMAIN" \
    -d "entity.$DOMAIN" \
    -d "api.$DOMAIN"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ SSL certificates obtained successfully${NC}"
else
    echo -e "${RED}✗ Failed to obtain SSL certificates${NC}"
    if [ "$RESTART_NGINX" = true ]; then
        docker-compose start nginx
    fi
    exit 1
fi

# Copy certificates to local ssl directory
echo -e "\n${YELLOW}Copying certificates...${NC}"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

cp "$CERT_PATH/fullchain.pem" ssl/fullchain.pem
cp "$CERT_PATH/privkey.pem" ssl/privkey.pem
cp "$CERT_PATH/chain.pem" ssl/chain.pem

chmod 644 ssl/fullchain.pem ssl/chain.pem
chmod 600 ssl/privkey.pem

echo -e "${GREEN}✓ Certificates copied to ./ssl/${NC}"

# Update nginx configuration
echo -e "\n${YELLOW}Updating Nginx configuration for SSL...${NC}"

# Uncomment SSL configuration in ssl.conf
if [ -f nginx/conf.d/ssl.conf ]; then
    sed -i 's/^# ssl_certificate /ssl_certificate /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_certificate_key /ssl_certificate_key /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_trusted_certificate /ssl_trusted_certificate /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_protocols /ssl_protocols /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_prefer_server_ciphers /ssl_prefer_server_ciphers /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_ciphers /ssl_ciphers /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_session /ssl_session /' nginx/conf.d/ssl.conf
    sed -i 's/^# ssl_stapling /ssl_stapling /' nginx/conf.d/ssl.conf
    sed -i 's/^# resolver /resolver /' nginx/conf.d/ssl.conf
    sed -i 's/^# add_header /add_header /' nginx/conf.d/ssl.conf
fi

# Restart nginx
if [ "$RESTART_NGINX" = true ]; then
    echo -e "\n${YELLOW}Restarting Nginx...${NC}"
    docker-compose up -d nginx
fi

# Setup auto-renewal
echo -e "\n${YELLOW}Setting up automatic certificate renewal...${NC}"

# Add cron job for renewal
CRON_CMD="0 3 * * * certbot renew --quiet --post-hook 'docker-compose restart nginx'"

if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo -e "${GREEN}✓ Auto-renewal cron job added${NC}"
else
    echo -e "${YELLOW}! Auto-renewal cron job already exists${NC}"
fi

echo -e "\n${GREEN}=== SSL Setup Complete ===${NC}"
echo -e "\nYour site is now accessible via HTTPS:"
echo -e "  https://$DOMAIN"
echo -e "  https://www.$DOMAIN"
echo -e "  https://druid.$DOMAIN"
echo -e "  https://geniess.$DOMAIN"
echo -e "  https://entity.$DOMAIN"
echo -e "  https://api.$DOMAIN"
echo -e "\nCertificates will be automatically renewed."
