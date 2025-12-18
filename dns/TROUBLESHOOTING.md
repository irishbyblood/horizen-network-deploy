# DNS Troubleshooting Guide

This guide helps resolve common DNS configuration issues for Horizen Network deployment.

## 🔍 Quick Diagnostics

Run these commands first to identify the issue:

```bash
# Check if DNS is resolving
dig horizen-network.com A +short

# Check with multiple DNS servers
dig @8.8.8.8 horizen-network.com A +short
dig @1.1.1.1 horizen-network.com A +short

# Trace DNS resolution path
dig horizen-network.com A +trace

# Run verification script
./dns/scripts/verify-dns.sh --verbose
```

## 🐛 Common Issues and Solutions

### Issue 1: DNS Not Resolving

**Symptoms:**
- `dig` returns nothing or "NXDOMAIN"
- Browser shows "Server not found"
- Verification script shows all red ✗

**Possible Causes:**

#### Cause A: DNS Records Not Created
**Solution:**
1. Log in to your DNS provider
2. Verify A record exists for main domain
3. Check if record shows as "active" or "published"
4. Wait 5-10 minutes and test again

```bash
# Verify in provider dashboard, then test
dig horizen-network.com A +short
```

#### Cause B: Wrong IP Address
**Solution:**
1. Get correct server IP:
   ```bash
   curl -4 ifconfig.me
   ```
2. Update A record in DNS provider
3. Wait for TTL to expire (check old TTL value)
4. Verify new IP:
   ```bash
   dig horizen-network.com A +short
   ```

#### Cause C: Nameservers Not Updated
**Solution:**
1. Check current nameservers:
   ```bash
   dig NS horizen-network.com +short
   ```
2. Compare with expected nameservers from DNS provider
3. If different, update at domain registrar
4. Wait up to 24-48 hours for propagation

### Issue 2: DNS Propagation Taking Too Long

**Symptoms:**
- Some DNS servers resolve, others don't
- whatsmydns.net shows mixed results
- Works in one location but not another

**Solutions:**

#### Solution A: Wait for Full Propagation
DNS propagation times:
- **Local ISP**: 5-30 minutes
- **Regional**: 1-4 hours
- **Global**: 2-48 hours

**Action:**
```bash
# Check specific DNS servers
dig @8.8.8.8 horizen-network.com +short  # Google DNS
dig @1.1.1.1 horizen-network.com +short  # Cloudflare DNS
dig @208.67.222.222 horizen-network.com +short  # OpenDNS

# Monitor with script
./dns/scripts/monitor-dns.sh
```

#### Solution B: Lower TTL Before Changes
If planning DNS changes:
1. **24-48 hours before**: Lower TTL to 300 (5 minutes)
2. **Wait**: For old TTL period to expire
3. **Make changes**: Update DNS records
4. **Verify**: Check propagation
5. **Raise TTL**: Back to 3600 after stable

#### Solution C: Clear DNS Cache
```bash
# Linux
sudo systemd-resolve --flush-caches
sudo service systemd-resolved restart

# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Windows (PowerShell)
ipconfig /flushdns

# Router
# Log in to router and find DNS cache clear option
```

### Issue 3: Subdomains Not Resolving

**Symptoms:**
- Main domain works: `horizen-network.com` resolves
- Subdomains fail: `druid.horizen-network.com` doesn't resolve
- CNAME queries return nothing

**Solutions:**

#### Solution A: CNAME Record Missing
```bash
# Check if CNAME exists
dig druid.horizen-network.com CNAME +short

# If empty, create CNAME record in DNS provider:
# Type: CNAME
# Name: druid
# Value: horizen-network.com (or @)
# TTL: 3600
```

#### Solution B: Wrong CNAME Target
```bash
# Verify CNAME points to correct target
dig druid.horizen-network.com CNAME

# Should return: horizen-network.com.
# Note the trailing dot (.)
```

#### Solution C: Using A Record Instead
Some providers don't require CNAME. Use A record:
```
Type: A
Name: druid
Value: YOUR_SERVER_IP
TTL: 3600
```

### Issue 4: SSL Certificate Fails

**Symptoms:**
- Let's Encrypt fails with "DNS validation failed"
- Certbot shows "Failed authorization procedure"
- SSL setup script errors

**Solutions:**

#### Solution A: DNS Not Fully Propagated
```bash
# Verify DNS is working globally
dig horizen-network.com A +short
dig @8.8.8.8 horizen-network.com A +short

# Check global propagation
# Visit: https://www.whatsmydns.net/?t=A&q=horizen-network.com

# Wait until most locations show green
# Then retry SSL setup:
sudo ./scripts/ssl-setup.sh
```

#### Solution B: CAA Records Blocking
```bash
# Check CAA records
dig horizen-network.com CAA +short

# Should include: 0 issue "letsencrypt.org"
# If other CA specified, add Let's Encrypt:
# Type: CAA
# Name: @
# Value: 0 issue "letsencrypt.org"
```

#### Solution C: Port 80 Not Accessible
```bash
# Test port 80
curl -I http://horizen-network.com

# Check firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check if Nginx is running
docker-compose ps nginx
docker-compose logs nginx
```

### Issue 5: Wildcard DNS Issues

**Symptoms:**
- Random subdomains resolve when they shouldn't
- Unexpected behavior with non-existent subdomains

**Solution:**
Remove wildcard (*) A record if present:
```bash
# Check for wildcard
dig random-test-123.horizen-network.com A +short

# If it resolves (shouldn't), remove wildcard A record:
# Delete: *.horizen-network.com A record
```

### Issue 6: WWW Redirect Not Working

**Symptoms:**
- www.horizen-network.com works but doesn't redirect
- Shows different content than main domain
- Certificate errors on www

**Solutions:**

#### Solution A: Add WWW CNAME
```bash
# Check www CNAME
dig www.horizen-network.com CNAME +short

# If missing, create:
# Type: CNAME
# Name: www
# Value: horizen-network.com
```

#### Solution B: Configure Nginx Redirect
Edit nginx configuration to redirect www to non-www:
```nginx
server {
    listen 80;
    server_name www.horizen-network.com;
    return 301 http://horizen-network.com$request_uri;
}
```

### Issue 7: CAA Record Errors

**Symptoms:**
- SSL fails with CAA error
- Certificate authority cannot issue certificate
- "CAA record prevents issuance"

**Solutions:**

#### Solution A: Add Let's Encrypt CAA
```bash
# Check current CAA records
dig horizen-network.com CAA

# Add Let's Encrypt authorization:
# Type: CAA
# Name: @
# Value: 0 issue "letsencrypt.org"

# Also add wildcard support:
# Type: CAA
# Name: @
# Value: 0 issuewild "letsencrypt.org"
```

#### Solution B: Remove Conflicting CAA
```bash
# If CAA exists for different CA, either:
# 1. Remove old CAA record
# 2. Add additional CAA record for Let's Encrypt
# 3. Both can coexist
```

### Issue 8: DNS Provider-Specific Issues

#### Cloudflare: Proxy Status Issues
**Problem:** SSL not working with orange cloud

**Solution:**
1. Set proxy to "DNS only" (gray cloud) initially
2. Complete SSL setup with Let's Encrypt
3. Then enable proxy (orange cloud) if desired

```bash
# Or use Cloudflare's free SSL instead:
# SSL/TLS → Full (Strict)
```

#### GoDaddy: Changes Not Saving
**Problem:** DNS changes revert after saving

**Solution:**
1. Clear browser cache
2. Try different browser
3. Disable browser extensions
4. Contact GoDaddy support

#### Namecheap: Trailing Dot Required
**Problem:** CNAME not working

**Solution:**
Add trailing dot to CNAME target:
- ❌ Wrong: `horizen-network.com`
- ✅ Right: `horizen-network.com.`

#### Route 53: Permissions Error
**Problem:** AWS API returns permission denied

**Solution:**
```bash
# Ensure IAM policy has Route53 permissions:
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:GetHostedZone"
    ],
    "Resource": "arn:aws:route53:::hostedzone/*"
  }]
}
```

### Issue 9: Slow DNS Resolution

**Symptoms:**
- Domain takes long time to resolve
- Intermittent timeouts
- High latency

**Solutions:**

#### Solution A: Lower TTL
```bash
# Reduce TTL to 300 seconds (5 minutes)
# This forces more frequent updates but may increase DNS queries
```

#### Solution B: Use Faster DNS Provider
Consider switching to:
- Cloudflare (fast, global network)
- AWS Route 53 (enterprise performance)
- DigitalOcean DNS (fast and free)

#### Solution C: Enable DNSSEC
```bash
# Enable DNSSEC if supported by provider
# Prevents DNS spoofing and may improve performance
```

### Issue 10: Conflicting DNS Records

**Symptoms:**
- Inconsistent resolution
- Different IPs returned randomly
- Some services work, others don't

**Solution:**
```bash
# List all DNS records
dig horizen-network.com ANY

# Look for:
# - Multiple A records (should be only one)
# - CNAME conflicts with A record (can't have both)
# - Duplicate records with different TTLs

# Delete duplicates and conflicts in DNS provider
```

## 🔧 Advanced Debugging

### DNS Trace
```bash
# Full DNS resolution trace
dig horizen-network.com A +trace

# This shows:
# 1. Root servers queried
# 2. TLD servers queried  
# 3. Authoritative nameservers
# 4. Final resolution
```

### Query Specific Record Types
```bash
# A record (IPv4)
dig horizen-network.com A

# AAAA record (IPv6)
dig horizen-network.com AAAA

# CNAME record
dig www.horizen-network.com CNAME

# CAA record
dig horizen-network.com CAA

# NS record (nameservers)
dig horizen-network.com NS

# SOA record (Start of Authority)
dig horizen-network.com SOA

# All records
dig horizen-network.com ANY
```

### Check DNS Propagation Script
```bash
# Create custom check script
for server in 8.8.8.8 1.1.1.1 208.67.222.222 9.9.9.9; do
    echo "Checking DNS $server:"
    dig @$server horizen-network.com A +short
    echo ""
done
```

### TCPDUMP DNS Queries
```bash
# Monitor live DNS traffic
sudo tcpdump -i any -n port 53

# Filter specific domain
sudo tcpdump -i any -n port 53 and host horizen-network.com
```

## 📞 Getting Help

If issues persist:

1. **Run verbose verification:**
   ```bash
   ./dns/scripts/verify-dns.sh --verbose
   ```

2. **Check provider status:**
   - Cloudflare: https://www.cloudflarestatus.com/
   - AWS: https://status.aws.amazon.com/
   - GoDaddy: https://status.godaddy.com/

3. **Contact DNS provider support** with:
   - Domain name
   - Issue description
   - Output from dig commands
   - Screenshots of DNS records

4. **Create GitHub issue** with:
   - Output from verification script
   - DNS provider used
   - Steps already attempted

## ✅ Prevention Checklist

Prevent DNS issues:

- [ ] Use low TTL (300) during setup
- [ ] Wait for propagation before SSL setup
- [ ] Document all DNS changes
- [ ] Test with multiple DNS servers
- [ ] Monitor DNS with automated scripts
- [ ] Keep backup of DNS configuration
- [ ] Use Infrastructure as Code (Terraform)
- [ ] Enable DNSSEC if supported
- [ ] Set up DNS monitoring/alerts

## 📚 Additional Resources

- **DNS Checker**: https://dnschecker.org/
- **What's My DNS**: https://www.whatsmydns.net/
- **DNS Propagation**: https://www.dnswatch.info/
- **dig Tutorial**: https://www.digwebinterface.com/
- **DNS Basics**: https://www.cloudflare.com/learning/dns/what-is-dns/

---

**Still stuck?** See [README.md](README.md) or create a GitHub issue with detailed diagnostics.
