# Cloudflare DNS Setup Guide

## 📖 Overview

Cloudflare is the **recommended DNS provider** for Horizen Network due to its excellent performance, free CDN, DDoS protection, and automatic SSL certificates. This guide covers both manual and automated setup.

## ✨ Why Cloudflare?

**Advantages:**
- ⚡ **Fast Global DNS** - 200+ data centers worldwide
- 🛡️ **Free DDoS Protection** - Included on free plan
- 🔒 **Free SSL Certificates** - Automatic when proxied
- 📊 **Analytics** - Traffic insights and metrics
- 🚀 **CDN** - Content delivery network included
- 🔧 **API Access** - Full automation support
- 💰 **Free Plan** - Generous free tier

**Disadvantages:**
- Requires nameserver change
- Must use Cloudflare nameservers
- Some features require paid plans

## 🚀 Quick Start (Manual Setup)

### Step 1: Create Cloudflare Account

1. Go to https://www.cloudflare.com/
2. Click "Sign Up" (top right)
3. Enter email and create password
4. Verify your email address

### Step 2: Add Your Domain

1. Log in to Cloudflare dashboard
2. Click "Add a Site" button
3. Enter `horizen-network.com`
4. Click "Add Site"
5. Select **Free Plan** (recommended for start)
6. Click "Continue"

### Step 3: Import Existing DNS Records

Cloudflare will scan your current DNS records:

1. Review imported records
2. Remove any unnecessary records
3. Click "Continue"

### Step 4: Update Nameservers

Cloudflare will provide two nameservers:

```
Example:
ava.ns.cloudflare.com
ben.ns.cloudflare.com
```

**Update at Your Domain Registrar:**

1. Log in to your domain registrar (GoDaddy, Namecheap, etc.)
2. Find "Nameservers" or "DNS Settings"
3. Change from registrar's nameservers to Cloudflare's
4. Save changes

**Wait for Propagation** (5 minutes to 24 hours)

### Step 5: Add Required DNS Records

Once nameservers are active, add these records:

#### A Record for Main Domain

```
Type: A
Name: @
IPv4 address: YOUR_SERVER_IP
Proxy status: DNS only (gray cloud)
TTL: Auto
```

**Why DNS only?** During initial setup, use "DNS only" to allow direct access for SSL setup. Enable proxy (orange cloud) later.

#### CNAME Records for Subdomains

```
Type: CNAME
Name: www
Target: horizen-network.com
Proxy status: Proxied (orange cloud)
TTL: Auto

Type: CNAME
Name: druid
Target: horizen-network.com
Proxy status: DNS only (gray cloud)
TTL: Auto

Type: CNAME
Name: geniess
Target: horizen-network.com
Proxy status: DNS only (gray cloud)
TTL: Auto

Type: CNAME
Name: entity
Target: horizen-network.com
Proxy status: DNS only (gray cloud)
TTL: Auto

Type: CNAME
Name: api
Target: horizen-network.com
Proxy status: DNS only (gray cloud)
TTL: Auto
```

#### CAA Records for SSL

```
Type: CAA
Name: @
Tag: issue
CA domain name: letsencrypt.org
TTL: Auto

Type: CAA
Name: @
Tag: issuewild
CA domain name: letsencrypt.org
TTL: Auto
```

### Step 6: Configure SSL/TLS Settings

1. Go to **SSL/TLS** tab
2. Select **Full (Strict)** mode
3. This ensures end-to-end encryption

**SSL/TLS Modes:**
- ❌ **Off** - No encryption (not recommended)
- ❌ **Flexible** - CF to visitor encrypted, CF to server not encrypted
- ⚠️ **Full** - Encrypted, but certificate can be self-signed
- ✅ **Full (Strict)** - Encrypted with valid certificate (recommended)

### Step 7: Configure Security Settings

**Under the "Security" tab:**

1. **Security Level**: Medium
2. **Challenge Passage**: 30 minutes
3. **Browser Integrity Check**: On

**Under "Firewall":**

1. Enable **DDoS Protection** (automatic)
2. Set up **Firewall Rules** (optional):
   ```
   Example: Block traffic from specific countries
   (Country equals CN) Then Block
   ```

### Step 8: Configure Performance Settings

**Under "Speed" tab:**

1. **Auto Minify**:
   - ✅ JavaScript
   - ✅ CSS
   - ✅ HTML

2. **Brotli**: On

3. **Rocket Loader**: Off (can cause issues with some apps)

4. **Always Use HTTPS**: On (after SSL is configured)

### Step 9: Verify DNS

```bash
# Check nameservers
dig NS horizen-network.com +short

# Should show Cloudflare nameservers
# Example:
# ava.ns.cloudflare.com.
# ben.ns.cloudflare.com.

# Check A record
dig horizen-network.com A +short
# Should return: YOUR_SERVER_IP

# Check CNAME records
dig www.horizen-network.com +short
dig druid.horizen-network.com +short
dig geniess.horizen-network.com +short
dig entity.horizen-network.com +short
dig api.horizen-network.com +short
```

## 🤖 Automated Setup (Using Cloudflare API)

### Prerequisites

1. **Get API Token**:
   - Go to https://dash.cloudflare.com/profile/api-tokens
   - Click "Create Token"
   - Use "Edit zone DNS" template
   - Set permissions: Zone.DNS (Edit)
   - Include specific zone: horizen-network.com
   - Create token and save it

2. **Get Zone ID**:
   - Go to domain overview in Cloudflare dashboard
   - Scroll down to "API" section on right sidebar
   - Copy "Zone ID"

3. **Get Server IP**:
   ```bash
   curl -4 ifconfig.me
   ```

### Setup Environment Variables

```bash
export CLOUDFLARE_API_TOKEN="your_api_token_here"
export CLOUDFLARE_ZONE_ID="your_zone_id_here"
export SERVER_IP="203.0.113.10"
```

### Run Automated Setup Script

```bash
cd /path/to/horizen-network-deploy
./dns/scripts/setup-cloudflare.sh
```

The script will:
- ✅ Create A record for main domain
- ✅ Create CNAME records for all subdomains
- ✅ Configure CAA records for Let's Encrypt
- ✅ Set appropriate TTL values
- ✅ Configure proxy settings
- ✅ Verify all records created successfully

### Manual API Examples

#### Create A Record
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "@",
    "content": "'${SERVER_IP}'",
    "ttl": 1,
    "proxied": false
  }'
```

#### Create CNAME Record
```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "www",
    "content": "horizen-network.com",
    "ttl": 1,
    "proxied": true
  }'
```

#### List All DNS Records
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json"
```

## 🔧 Advanced Configuration

### Page Rules (Optimize Performance)

Create page rules for better performance:

1. Go to **Rules** > **Page Rules**
2. Create rule for `www.horizen-network.com/*`:
   - Forwarding URL: 301 Permanent Redirect
   - Destination: `https://horizen-network.com/$1`

3. Create rule for `horizen-network.com/*`:
   - Cache Level: Cache Everything
   - Edge Cache TTL: 1 month

### Firewall Rules

Protect your infrastructure:

```
Example Rules:

1. Block bad bots:
   (cf.client.bot) Then Block

2. Rate limiting:
   (http.request.uri.path contains "/api/") Then Challenge

3. Country-based:
   (ip.geoip.country in {"CN" "RU"}) Then Challenge
```

### Load Balancing (Paid Feature)

For high availability:

1. Go to **Traffic** > **Load Balancing**
2. Create origin pool with multiple servers
3. Configure health checks
4. Set up geographic steering

## 🔒 Security Best Practices

### 1. Enable DNSSEC

1. Go to **DNS** tab
2. Click **DNSSEC** section
3. Click "Enable DNSSEC"
4. Copy DS records
5. Add DS records at your domain registrar

### 2. Enable HSTS

1. Go to **SSL/TLS** > **Edge Certificates**
2. Enable **HTTP Strict Transport Security (HSTS)**
3. Set Max Age: 6 months
4. Include subdomains: Yes
5. Preload: No (initially)

### 3. Enable WAF (Web Application Firewall)

On paid plans:
1. Go to **Security** > **WAF**
2. Enable managed rulesets
3. Configure custom rules as needed

### 4. Configure Security Headers

Add security headers via Transform Rules:
```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

## 📊 Monitoring and Analytics

### Analytics Dashboard

1. Go to **Analytics & Logs**
2. View:
   - Total requests
   - Bandwidth usage
   - Unique visitors
   - Threats blocked
   - Traffic by country

### Email Notifications

Set up alerts:
1. Go to **Notifications**
2. Enable alerts for:
   - SSL/TLS certificate expiration
   - DDoS attacks
   - Health check failures
   - Zone changes

## 🐛 Troubleshooting

### Issue: Cloudflare Nameservers Not Active

**Symptoms**: Dashboard shows "Pending Nameserver Update"

**Solution**:
1. Verify nameservers at registrar
2. Wait 24-48 hours for full propagation
3. Use `dig NS horizen-network.com` to check
4. Contact registrar support if stuck

### Issue: 521 Error (Web Server Is Down)

**Symptoms**: "Web server is down" error

**Solution**:
1. Check if origin server is running
2. Verify firewall allows Cloudflare IPs
3. Check server error logs
4. Temporarily set proxy to "DNS only"

### Issue: 525 Error (SSL Handshake Failed)

**Symptoms**: Cannot establish SSL connection

**Solution**:
1. Verify SSL certificate is valid on origin
2. Change SSL mode to "Flexible" temporarily
3. Obtain valid SSL certificate (Let's Encrypt)
4. Switch back to "Full (Strict)"

### Issue: Too Many Redirects

**Symptoms**: "ERR_TOO_MANY_REDIRECTS" in browser

**Solution**:
1. Check SSL/TLS mode (use Full or Full Strict)
2. Verify Nginx isn't forcing HTTPS when CF is flexible
3. Check for redirect loops in configuration
4. Disable "Always Use HTTPS" temporarily

## 📖 Useful Cloudflare Commands

### Using cloudflare-cli (npm package)

Install:
```bash
npm install -g cloudflare-cli
```

Commands:
```bash
# List zones
cloudflare-cli zones list

# List DNS records
cloudflare-cli dns-records list --zone=horizen-network.com

# Add A record
cloudflare-cli dns-records add --zone=horizen-network.com \
  --type=A --name=@ --content=203.0.113.10

# Delete record
cloudflare-cli dns-records delete --zone=horizen-network.com \
  --id=RECORD_ID
```

### Using wrangler (Cloudflare Workers CLI)

```bash
# Install
npm install -g wrangler

# Login
wrangler login

# Deploy worker
wrangler deploy
```

## 🔗 Additional Resources

- **Cloudflare Dashboard**: https://dash.cloudflare.com/
- **API Documentation**: https://developers.cloudflare.com/api/
- **Learning Center**: https://www.cloudflare.com/learning/
- **Status Page**: https://www.cloudflarestatus.com/
- **Community Forums**: https://community.cloudflare.com/
- **Support**: https://support.cloudflare.com/

## ✅ Post-Setup Checklist

After Cloudflare setup:

- [ ] Nameservers updated at registrar
- [ ] Nameservers active in Cloudflare (check dashboard)
- [ ] A record created for main domain
- [ ] CNAME records created for all subdomains
- [ ] CAA records added for Let's Encrypt
- [ ] SSL/TLS mode set to Full (Strict)
- [ ] Security features configured
- [ ] Performance optimization enabled
- [ ] DNS verified with dig commands
- [ ] Tested website access
- [ ] SSL certificate obtained (Let's Encrypt)
- [ ] Enabled proxy (orange cloud) after SSL works
- [ ] Set up monitoring and alerts

## 🎯 Next Steps

1. Wait for DNS propagation (use https://www.whatsmydns.net/)
2. Verify DNS: `./dns/scripts/verify-dns.sh`
3. Deploy infrastructure: `./scripts/deploy.sh prod`
4. Setup SSL: `sudo ./scripts/ssl-setup.sh`
5. Enable Cloudflare proxy (orange cloud) for www subdomain
6. Configure additional security rules as needed

---

**Note**: Replace placeholder values (YOUR_SERVER_IP, tokens, zone IDs) with your actual values.

For additional help, see [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md) or Cloudflare support.
