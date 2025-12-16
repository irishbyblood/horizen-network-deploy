# Terraform Configuration for Cloudflare DNS
# Manages DNS records for Horizen Network infrastructure

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Variables
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for horizen-network.com"
  type        = string
}

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "horizen-network.com"
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
}

variable "ttl" {
  description = "Default TTL for DNS records (1 = automatic)"
  type        = number
  default     = 1
}

# Provider configuration
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# A Record for main domain
resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = var.server_ip
  type    = "A"
  ttl     = var.ttl
  proxied = false  # Set to false initially for SSL setup
  comment = "Main domain A record"
}

# CNAME Record for www (proxied for CDN benefits)
resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = var.domain
  type    = "CNAME"
  ttl     = var.ttl
  proxied = true  # Enable Cloudflare proxy for www
  comment = "WWW subdomain redirect"
}

# CNAME Records for application subdomains
resource "cloudflare_record" "app_subdomains" {
  for_each = toset(["druid", "geniess", "entity", "api"])
  
  zone_id = var.cloudflare_zone_id
  name    = each.key
  value   = var.domain
  type    = "CNAME"
  ttl     = var.ttl
  proxied = false  # DNS only for direct server access
  comment = "Application subdomain: ${each.key}"
}

# CAA Record - Issue
resource "cloudflare_record" "caa_issue" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CAA"
  
  data {
    flags = 0
    tag   = "issue"
    value = "letsencrypt.org"
  }
  
  comment = "Allow Let's Encrypt to issue SSL certificates"
}

# CAA Record - Wildcard Issue
resource "cloudflare_record" "caa_issuewild" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CAA"
  
  data {
    flags = 0
    tag   = "issuewild"
    value = "letsencrypt.org"
  }
  
  comment = "Allow Let's Encrypt to issue wildcard SSL certificates"
}

# Optional: TXT Record for SPF (if not using email)
resource "cloudflare_record" "spf" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = "v=spf1 -all"
  type    = "TXT"
  ttl     = var.ttl
  comment = "SPF record to prevent email spoofing"
}

# Outputs
output "dns_records_created" {
  description = "List of DNS records created"
  value = {
    main_domain = cloudflare_record.main.hostname
    www         = cloudflare_record.www.hostname
    subdomains  = [for record in cloudflare_record.app_subdomains : record.hostname]
  }
}

output "main_domain_ip" {
  description = "IP address of main domain"
  value       = cloudflare_record.main.value
}

output "nameservers" {
  description = "Cloudflare nameservers (check Cloudflare dashboard)"
  value       = "Check Cloudflare dashboard for nameservers"
}

# Usage Instructions:
# 
# 1. Create terraform.tfvars file:
#    cloudflare_api_token = "your_api_token"
#    cloudflare_zone_id   = "your_zone_id"
#    server_ip            = "203.0.113.10"
#
# 2. Initialize Terraform:
#    terraform init
#
# 3. Plan the changes:
#    terraform plan
#
# 4. Apply the configuration:
#    terraform apply
#
# 5. Verify DNS records:
#    ./dns/scripts/verify-dns.sh
#
# Note: Store terraform.tfvars securely and add it to .gitignore
