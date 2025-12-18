# GoDaddy DNS Setup Guide

## 📖 Overview

GoDaddy is one of the world's largest domain registrars. If you registered your domain with GoDaddy, you can use their built-in DNS management to configure records for Horizen Network.

## 🚀 Setup Instructions

### Step 1: Access DNS Management

1. Log in to https://account.godaddy.com/
2. Click on your username (top right)
3. Select "My Products"
4. Find "horizen-network.com" in your domains list
5. Click the three-dot menu (...) next to the domain
6. Select "Manage DNS"

### Step 2: Add A Record for Main Domain

1. In the DNS Management page, find the "Records" section
2. Click "Add" button
3. Select record type: **A**
4. Configure:
   ```
   Type: A
   Host: @
   Points to: YOUR_SERVER_IP (e.g., 203.0.113.10)
   TTL: 1 Hour (or Custom: 3600 seconds)
   ```
5. Click "Save"

### Step 3: Add CNAME Records for Subdomains

Add each subdomain as a CNAME record:

#### WWW Subdomain
```
Type: CNAME
Host: www
Points to: @ (or horizen-network.com)
TTL: 1 Hour
```

#### Druid Subdomain
```
Type: CNAME
Host: druid
Points to: @
TTL: 1 Hour
```

#### Geniess Subdomain
```
Type: CNAME
Host: geniess
Points to: @
TTL: 1 Hour
```

#### Entity Subdomain
```
Type: CNAME
Host: entity
Points to: @
TTL: 1 Hour
```

#### API Subdomain
```
Type: CNAME
Host: api
Points to: @
TTL: 1 Hour
```

**For each record:**
1. Click "Add" button
2. Select "CNAME" type
3. Fill in host and points to values
4. Click "Save"

### Step 4: Add CAA Records (Optional)

GoDaddy supports CAA records for SSL certificate authorization:

1. Click "Add" button
2. Select record type: **CAA**
3. Configure:
   ```
   Type: CAA
   Host: @
   Tag: issue
   Value: letsencrypt.org
   TTL: 1 Hour
   ```
4. Click "Save"
5. Repeat for wildcard:
   ```
   Type: CAA
   Host: @
   Tag: issuewild
   Value: letsencrypt.org
   TTL: 1 Hour
   ```

## ✅ Verification

### Check DNS Records

After adding records, verify they're active:

```bash
# Check main domain
dig horizen-network.com A +short

# Check subdomains
dig www.horizen-network.com +short
dig druid.horizen-network.com +short
dig geniess.horizen-network.com +short
dig entity.horizen-network.com +short
dig api.horizen-network.com +short
```

### DNS Propagation Time

GoDaddy DNS changes typically propagate in:
- **Minimum**: 10-30 minutes
- **Average**: 1-2 hours
- **Maximum**: 24-48 hours

Check propagation: https://www.whatsmydns.net/

## 🔧 Advanced Options

### Custom Nameservers

If you want to use external DNS (Cloudflare, Route 53, etc.):

1. In "My Products", find your domain
2. Click the three-dot menu (...)
3. Select "Manage DNS"
4. Scroll to "Nameservers" section
5. Click "Change"
6. Select "Enter my own nameservers (advanced)"
7. Enter nameservers (e.g., Cloudflare's):
   ```
   ava.ns.cloudflare.com
   ben.ns.cloudflare.com
   ```
8. Click "Save"

**Note**: Changing nameservers will make GoDaddy DNS management inactive. All DNS must be managed at the new provider.

### DNSSEC

Enable DNSSEC for enhanced security:

1. In DNS Management, scroll to "Additional Settings"
2. Find "DNSSEC" section
3. Click "Manage"
4. Click "Add" to enable DNSSEC
5. Follow wizard to configure

**Note**: DNSSEC requires compatible nameservers and registrar support.

## 🐛 Common Issues

### Issue: Records Not Saving

**Symptoms**: Changes revert after saving

**Solution**:
1. Clear browser cache
2. Try different browser
3. Disable browser extensions
4. Contact GoDaddy support

### Issue: DNS Not Propagating

**Symptoms**: dig shows old IP or no result

**Solution**:
1. Wait longer (up to 24 hours)
2. Clear local DNS cache: `sudo systemd-resolve --flush-caches`
3. Check using multiple DNS servers:
   ```bash
   dig @8.8.8.8 horizen-network.com
   dig @1.1.1.1 horizen-network.com
   ```
4. Verify record in GoDaddy dashboard

### Issue: Subdomain Shows "Can't Find Server"

**Symptoms**: Main domain works but subdomains don't

**Solution**:
1. Verify CNAME record exists
2. Ensure "Points to" is @ or horizen-network.com
3. Check for typos in host field
4. Wait for DNS propagation
5. Test with: `dig subdomain.horizen-network.com +trace`

### Issue: CAA Record Issues with SSL

**Symptoms**: Let's Encrypt fails with CAA error

**Solution**:
1. Verify CAA record syntax
2. Check tag is "issue" or "issuewild"
3. Value should be just "letsencrypt.org" (no quotes)
4. Wait 30 minutes for propagation
5. Retry SSL setup: `sudo ./scripts/ssl-setup.sh`

## 💡 Tips and Best Practices

1. **Use @ for root domain**: GoDaddy uses @ to represent the root domain
2. **TTL recommendations**: Use 1 hour (default) for production
3. **Before major changes**: Lower TTL to 5 minutes, wait for old TTL to expire
4. **Test before SSL**: Ensure DNS works before running SSL setup
5. **Screenshot records**: Keep a backup of your DNS configuration

## 📊 GoDaddy DNS Management Features

**Included:**
- ✅ A records
- ✅ CNAME records
- ✅ MX records (email)
- ✅ TXT records
- ✅ CAA records
- ✅ SRV records
- ✅ AAAA records (IPv6)
- ✅ NS records

**Limitations:**
- No built-in CDN
- No DDoS protection (basic only)
- No automatic SSL
- Slower propagation than Cloudflare
- No API on lower plans

## 📖 Additional Resources

- **GoDaddy DNS Help**: https://www.godaddy.com/help/manage-dns-680
- **Support**: https://www.godaddy.com/contact-us
- **Video Tutorials**: https://www.godaddy.com/help/video-tutorials-for-domains
- **Community Forum**: https://community.godaddy.com/

## 🔗 Alternative Providers

If you want better features, consider:
- **Cloudflare** - Free CDN, DDoS protection, faster DNS
- **AWS Route 53** - Enterprise features, API access
- **DigitalOcean DNS** - Free, fast, simple

You can keep your domain registered at GoDaddy but use their nameservers.

## ✅ Verification Checklist

- [ ] Logged into GoDaddy account
- [ ] Found domain in "My Products"
- [ ] Accessed DNS Management
- [ ] Added A record for @
- [ ] Added CNAME for www
- [ ] Added CNAME for druid
- [ ] Added CNAME for geniess
- [ ] Added CNAME for entity
- [ ] Added CNAME for api
- [ ] Added CAA records (optional)
- [ ] Verified records in GoDaddy dashboard
- [ ] Tested with dig commands
- [ ] Checked propagation status
- [ ] Waited for full propagation
- [ ] Proceeded with deployment

---

For more help, see [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md) or contact GoDaddy support.
