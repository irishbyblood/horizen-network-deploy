#!/bin/bash

# DNS Records Export Script
# Exports DNS configuration to multiple formats

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN="${DOMAIN:-horizen-network.com}"
SERVER_IP="${SERVER_IP:-203.0.113.10}"
OUTPUT_DIR="dns/exports"
FORMAT="${1:-all}"

mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}=== DNS Records Export ===${NC}\n"

# Export to JSON
export_json() {
    local file="$OUTPUT_DIR/dns-records.json"
    echo -e "${YELLOW}Exporting to JSON...${NC}"
    
    cat > "$file" <<EOF
{
  "domain": "${DOMAIN}",
  "server_ip": "${SERVER_IP}",
  "ttl": 3600,
  "records": [
    {
      "type": "A",
      "name": "@",
      "value": "${SERVER_IP}",
      "ttl": 3600,
      "description": "Main domain"
    },
    {
      "type": "CNAME",
      "name": "www",
      "value": "${DOMAIN}",
      "ttl": 3600,
      "description": "WWW redirect"
    },
    {
      "type": "CNAME",
      "name": "druid",
      "value": "${DOMAIN}",
      "ttl": 3600,
      "description": "Apache Druid UI"
    },
    {
      "type": "CNAME",
      "name": "geniess",
      "value": "${DOMAIN}",
      "ttl": 3600,
      "description": "Geniess AI platform"
    },
    {
      "type": "CNAME",
      "name": "entity",
      "value": "${DOMAIN}",
      "ttl": 3600,
      "description": "Entity unified AI app"
    },
    {
      "type": "CNAME",
      "name": "api",
      "value": "${DOMAIN}",
      "ttl": 3600,
      "description": "API endpoint"
    },
    {
      "type": "CAA",
      "name": "@",
      "value": "0 issue \"letsencrypt.org\"",
      "ttl": 3600,
      "description": "SSL certificate authority"
    },
    {
      "type": "CAA",
      "name": "@",
      "value": "0 issuewild \"letsencrypt.org\"",
      "ttl": 3600,
      "description": "Wildcard SSL authority"
    }
  ]
}
EOF
    
    echo -e "${GREEN}✓ Exported to: $file${NC}"
}

# Export to CSV
export_csv() {
    local file="$OUTPUT_DIR/dns-records.csv"
    echo -e "${YELLOW}Exporting to CSV...${NC}"
    
    cat > "$file" <<EOF
Type,Name,Value,TTL,Description
A,@,${SERVER_IP},3600,Main domain
CNAME,www,${DOMAIN},3600,WWW redirect
CNAME,druid,${DOMAIN},3600,Apache Druid UI
CNAME,geniess,${DOMAIN},3600,Geniess AI platform
CNAME,entity,${DOMAIN},3600,Entity unified AI app
CNAME,api,${DOMAIN},3600,API endpoint
CAA,@,0 issue "letsencrypt.org",3600,SSL certificate authority
CAA,@,0 issuewild "letsencrypt.org",3600,Wildcard SSL authority
EOF
    
    echo -e "${GREEN}✓ Exported to: $file${NC}"
}

# Export to Terraform
export_terraform() {
    local file="$OUTPUT_DIR/dns-records.tf"
    echo -e "${YELLOW}Exporting to Terraform...${NC}"
    
    cat > "$file" <<'EOF'
# DNS Records Configuration for Horizen Network
# This file can be used with Cloudflare, AWS Route53, or DigitalOcean providers

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "horizen-network.com"
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
  default     = "203.0.113.10"
}

# Example for Cloudflare provider
# Uncomment and configure for your provider

# terraform {
#   required_providers {
#     cloudflare = {
#       source  = "cloudflare/cloudflare"
#       version = "~> 4.0"
#     }
#   }
# }

# provider "cloudflare" {
#   api_token = var.cloudflare_api_token
# }

# A Record for main domain
# resource "cloudflare_record" "main" {
#   zone_id = var.zone_id
#   name    = "@"
#   value   = var.server_ip
#   type    = "A"
#   ttl     = 3600
#   proxied = false
# }

# CNAME Records
# resource "cloudflare_record" "cname" {
#   for_each = toset(["www", "druid", "geniess", "entity", "api"])
#   
#   zone_id = var.zone_id
#   name    = each.key
#   value   = var.domain
#   type    = "CNAME"
#   ttl     = 3600
#   proxied = each.key == "www"
# }

# CAA Records
# resource "cloudflare_record" "caa_issue" {
#   zone_id = var.zone_id
#   name    = "@"
#   type    = "CAA"
#   data {
#     flags = 0
#     tag   = "issue"
#     value = "letsencrypt.org"
#   }
# }
EOF
    
    echo -e "${GREEN}✓ Exported to: $file${NC}"
}

# Export to BIND zone file
export_bind() {
    local file="$OUTPUT_DIR/zone-file.txt"
    echo -e "${YELLOW}Exporting to BIND zone file...${NC}"
    
    cat > "$file" <<EOF
\$ORIGIN ${DOMAIN}.
\$TTL 3600

; SOA Record
@       IN  SOA  ns1.${DOMAIN}. admin.${DOMAIN}. (
                $(date +%Y%m%d)01  ; Serial
                7200        ; Refresh
                3600        ; Retry
                1209600     ; Expire
                3600 )      ; Minimum TTL

; A Record
@       IN  A        ${SERVER_IP}

; CNAME Records
www     IN  CNAME    ${DOMAIN}.
druid   IN  CNAME    ${DOMAIN}.
geniess IN  CNAME    ${DOMAIN}.
entity  IN  CNAME    ${DOMAIN}.
api     IN  CNAME    ${DOMAIN}.

; CAA Records
@       IN  CAA      0 issue "letsencrypt.org"
@       IN  CAA      0 issuewild "letsencrypt.org"
EOF
    
    echo -e "${GREEN}✓ Exported to: $file${NC}"
}

# Main export logic
case "$FORMAT" in
    json)
        export_json
        ;;
    csv)
        export_csv
        ;;
    terraform|tf)
        export_terraform
        ;;
    bind|zone)
        export_bind
        ;;
    all|*)
        export_json
        export_csv
        export_terraform
        export_bind
        ;;
esac

echo -e "\n${GREEN}✓ Export complete!${NC}"
echo -e "Files saved to: ${OUTPUT_DIR}/"
ls -lh "$OUTPUT_DIR"
