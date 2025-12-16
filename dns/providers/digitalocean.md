# DigitalOcean DNS Setup Guide

## 📖 Overview

DigitalOcean offers free, fast DNS hosting with a simple interface and CLI support. Perfect for users hosting on DigitalOcean or those wanting straightforward DNS management.

## 🚀 Setup Instructions

### Step 1: Add Domain to DigitalOcean

#### Via Dashboard

1. Log in to https://cloud.digitalocean.com/
2. Click "Networking" in left sidebar
3. Click "Domains" tab
4. In "Add a domain" field, enter: `horizen-network.com`
5. Click "Add Domain"

#### Via doctl CLI

```bash
# Install doctl
snap install doctl
# or
brew install doctl

# Authenticate
doctl auth init

# Add domain
doctl compute domain create horizen-network.com
```

### Step 2: Update Nameservers at Registrar

DigitalOcean provides these nameservers:
```
ns1.digitalocean.com
ns2.digitalocean.com
ns3.digitalocean.com
```

1. Log in to your domain registrar
2. Find nameserver settings
3. Replace with DigitalOcean nameservers above
4. Save and wait for propagation (up to 24 hours)

### Step 3: Create DNS Records

#### Via Dashboard

Click on your domain, then add records:

**A Record:**
```
Type: A
Hostname: @
Will Direct To: YOUR_SERVER_IP
TTL: 3600
```

**CNAME Records:**
```
Type: CNAME
Hostname: www
Is An Alias Of: @
TTL: 3600

Type: CNAME
Hostname: druid
Is An Alias Of: @
TTL: 3600

Type: CNAME
Hostname: geniess
Is An Alias Of: @
TTL: 3600

Type: CNAME
Hostname: entity
Is An Alias Of: @
TTL: 3600

Type: CNAME
Hostname: api
Is An Alias Of: @
TTL: 3600
```

**CAA Records:**
```
Type: CAA
Hostname: @
Tag: issue
Value: letsencrypt.org
TTL: 3600
```

#### Via doctl CLI

```bash
# Set variables
DOMAIN="horizen-network.com"
SERVER_IP="203.0.113.10"

# Create A record
doctl compute domain records create $DOMAIN \
  --record-type A \
  --record-name @ \
  --record-data $SERVER_IP \
  --record-ttl 3600

# Create CNAME records
for subdomain in www druid geniess entity api; do
  doctl compute domain records create $DOMAIN \
    --record-type CNAME \
    --record-name $subdomain \
    --record-data @ \
    --record-ttl 3600
done

# Create CAA record
doctl compute domain records create $DOMAIN \
  --record-type CAA \
  --record-name @ \
  --record-data "0 issue letsencrypt.org" \
  --record-ttl 3600
```

## ✅ Verification

```bash
# List all records
doctl compute domain records list horizen-network.com

# Check DNS resolution
dig horizen-network.com A +short
dig www.horizen-network.com CNAME +short
dig @ns1.digitalocean.com horizen-network.com A +short
```

## 🔧 Advanced Features

### Automatic Droplet DNS

If using DigitalOcean Droplet:

```bash
# Point to droplet by name
doctl compute domain records create $DOMAIN \
  --record-type A \
  --record-name @ \
  --record-data DROPLET_IP

# Or use Floating IP
doctl compute domain records create $DOMAIN \
  --record-type A \
  --record-name @ \
  --record-data FLOATING_IP
```

### Bulk Import

Create `records.txt`:
```
@       A       203.0.113.10    3600
www     CNAME   @               3600
druid   CNAME   @               3600
geniess CNAME   @               3600
entity  CNAME   @               3600
api     CNAME   @               3600
```

Import (via script):
```bash
while IFS=$'\t' read -r name type data ttl; do
  doctl compute domain records create horizen-network.com \
    --record-name "$name" \
    --record-type "$type" \
    --record-data "$data" \
    --record-ttl "$ttl"
done < records.txt
```

### API Access

Use DigitalOcean API directly:

```bash
# Get personal access token from dashboard
TOKEN="your_token_here"

# Create A record
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"type":"A","name":"@","data":"203.0.113.10","ttl":3600}' \
  "https://api.digitalocean.com/v2/domains/horizen-network.com/records"

# List records
curl -X GET \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.digitalocean.com/v2/domains/horizen-network.com/records"
```

## 🔄 Automation with Terraform

```hcl
# digitalocean-dns.tf
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_domain" "main" {
  name = "horizen-network.com"
}

resource "digitalocean_record" "main" {
  domain = digitalocean_domain.main.name
  type   = "A"
  name   = "@"
  value  = var.server_ip
  ttl    = 3600
}

resource "digitalocean_record" "cname" {
  for_each = toset(["www", "druid", "geniess", "entity", "api"])
  
  domain = digitalocean_domain.main.name
  type   = "CNAME"
  name   = each.key
  value  = "@"
  ttl    = 3600
}

resource "digitalocean_record" "caa" {
  domain = digitalocean_domain.main.name
  type   = "CAA"
  name   = "@"
  value  = "0 issue \"letsencrypt.org\""
  ttl    = 3600
}
```

Apply:
```bash
export TF_VAR_do_token="your_token"
export TF_VAR_server_ip="203.0.113.10"
terraform init
terraform apply
```

## 💰 Pricing

**Free!** DigitalOcean DNS is completely free:
- ✅ Unlimited domains
- ✅ Unlimited records
- ✅ No query charges
- ✅ Global anycast network

## 🐛 Common Issues

### Issue: Nameservers Not Updating

**Solution**:
1. Verify nameservers at registrar
2. Some registrars have 24-48 hour delays
3. Check with: `dig NS horizen-network.com +short`
4. Contact registrar support if stuck

### Issue: Record Not Found

**Solution**:
1. Check record exists: `doctl compute domain records list horizen-network.com`
2. Verify correct syntax (@, not blank)
3. Wait 5-10 minutes for propagation
4. Clear DNS cache: `sudo systemd-resolve --flush-caches`

## 💡 Tips

- **Use @** for root domain (not blank or domain name)
- **TTL 3600** is good default (1 hour)
- **doctl** is powerful for automation
- **API access** available with personal token
- **Free** for all DigitalOcean users
- **Fast propagation** - usually 5-10 minutes

## 📖 Resources

- **Documentation**: https://docs.digitalocean.com/products/networking/dns/
- **API Reference**: https://docs.digitalocean.com/reference/api/api-reference/#tag/Domain-Records
- **doctl Guide**: https://docs.digitalocean.com/reference/doctl/
- **Support**: https://www.digitalocean.com/support/

## ✅ Checklist

- [ ] Created DigitalOcean account
- [ ] Added domain to DigitalOcean
- [ ] Updated nameservers at registrar
- [ ] Waited for nameserver propagation
- [ ] Created A record for @
- [ ] Created CNAME records for subdomains
- [ ] Added CAA records
- [ ] Verified with dig commands
- [ ] Tested with doctl (optional)
- [ ] Checked propagation globally

## 🎯 Quick Reference

```bash
# List domains
doctl compute domain list

# List records
doctl compute domain records list horizen-network.com

# Delete record
doctl compute domain records delete horizen-network.com RECORD_ID

# Update record (delete and recreate)
doctl compute domain records delete horizen-network.com RECORD_ID
doctl compute domain records create horizen-network.com \
  --record-type A --record-name @ --record-data NEW_IP
```

---

For more help, see [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
