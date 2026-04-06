# Cloudflare DNS Setup for Horizen Network

Complete guide for configuring DNS on Cloudflare for horizen-network.com.

## Prerequisites

1. Domain registered and added to Cloudflare
2. Cloudflare nameservers configured at your registrar
3. Server IP address ready
4. Cloudflare account with DNS management access

## Quick Setup

### Step 1: Add Your Domain to Cloudflare

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click "Add a Site"
3. Enter `horizen-network.com`
4. Select the Free plan (or your preferred plan)
5. Click "Add Site"

### Step 2: Update Nameservers

Cloudflare will provide nameservers like:
```
homer.ns.cloudflare.com
marge.ns.cloudflare.com
```

Update these at your domain registrar (where you bought the domain).

**Wait for nameserver propagation** (can take 24-48 hours).

### Step 3: Configure DNS Records

Navigate to DNS settings and add these records:

#### Required Records

| Type | Name | Content | Proxy Status | TTL |
|------|------|---------|--------------|-----|
| A | @ | YOUR_SERVER_IP | DNS only | Auto |
| CNAME | www | horizen-network.com | DNS only | Auto |
| A | druid | YOUR_SERVER_IP | DNS only | Auto |
| A | geniess | YOUR_SERVER_IP | DNS only | Auto |
| A | entity | YOUR_SERVER_IP | DNS only | Auto |

**Important**: 
- Replace `YOUR_SERVER_IP` with your actual server IP (e.g., 203.0.113.10)
- The **www CNAME record is REQUIRED** for www.horizen-network.com to work
- Set "Proxy status" to "DNS only" initially (orange cloud OFF)

#### How to Add Records

1. Click "Add record"
2. Select record type (A or CNAME)
3. Enter Name (e.g., www, druid, geniess)
4. Enter Content/Value
5. Set Proxy status to "DNS only" (click orange cloud to turn it grey)
6. Click "Save"

#### Screenshot Example

```
Type: CNAME
Name: www
Target: horizen-network.com
Proxy status: DNS only (grey cloud)
TTL: Auto
```

### Step 4: Verify DNS Configuration

Wait 5-10 minutes for DNS changes to propagate, then verify:

```bash
# Check main domain
dig horizen-network.com +short

# Check www subdomain (IMPORTANT)
dig www.horizen-network.com +short

# Check subdomains
dig druid.horizen-network.com +short
dig geniess.horizen-network.com +short
dig entity.horizen-network.com +short
```

You can also use Cloudflare's built-in DNS checker or run:
```bash
./dns/validation-script.sh
```

## SSL/TLS Configuration

### Option 1: Let's Encrypt (Recommended)

1. Keep "Proxy status" as "DNS only" (grey cloud)
2. On server, run: `sudo ./scripts/ssl-setup.sh`
3. Let's Encrypt will verify domain ownership via HTTP
4. Certificates will be installed on your server
5. After SSL is working, you can enable Cloudflare proxy if desired

### Option 2: Cloudflare SSL (Simpler but less control)

1. Set "Proxy status" to "Proxied" (orange cloud)
2. Go to SSL/TLS settings in Cloudflare
3. Set SSL mode to "Full" or "Full (strict)"
4. Cloudflare will provide free SSL certificate
5. Install Cloudflare Origin Certificate on your server

**Recommended**: Use Let's Encrypt (Option 1) for full control.

## Advanced Configuration

### Enable Cloudflare Proxy (After SSL Setup)

Once SSL is working with Let's Encrypt:

1. Go to DNS settings
2. Click on the orange/grey cloud icon next to each record
3. Change from "DNS only" to "Proxied"

Benefits of proxying through Cloudflare:
- DDoS protection
- CDN acceleration
- Web Application Firewall (WAF)
- Analytics
- Caching

**Note**: When proxied, you'll see Cloudflare's IP addresses, not your server's.

### Page Rules

Create page rules for better caching and security:

1. Go to "Rules" > "Page Rules"
2. Add rules:

**WWW to non-WWW redirect** (if you prefer non-www):
```
URL: www.horizen-network.com/*
Setting: Forwarding URL
Status Code: 301
Destination: https://horizen-network.com/$1
```

**Cache everything for static assets**:
```
URL: *horizen-network.com/css/*
Settings:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 1 month
```

### Security Settings

Recommended security settings in Cloudflare:

1. **SSL/TLS**:
   - Mode: Full (strict)
   - Always Use HTTPS: ON
   - HTTP Strict Transport Security (HSTS): Enable

2. **Security**:
   - Security Level: Medium
   - Challenge Passage: 30 minutes
   - Browser Integrity Check: ON

3. **Firewall**:
   - Add firewall rules to block suspicious traffic
   - Enable Bot Fight Mode (free)

4. **Speed**:
   - Auto Minify: HTML, CSS, JavaScript
   - Brotli: ON
   - HTTP/2: ON
   - HTTP/3 (QUIC): ON

### CAA Records

Add Certificate Authority Authorization records:

```
Type: CAA
Name: @
Tag: issue
Value: letsencrypt.org
```

This restricts which CAs can issue certificates for your domain.

### Email Records (Optional)

If you want to use email with your domain:

```
Type: MX
Name: @
Priority: 10
Content: mail.yourmailserver.com
```

Add SPF record:
```
Type: TXT
Name: @
Content: v=spf1 include:_spf.google.com ~all
```

## Troubleshooting

### DNS Not Propagating

**Problem**: Changes not visible after 10 minutes

**Solutions**:
1. Flush your local DNS cache:
   ```bash
   # Linux
   sudo systemd-resolve --flush-caches
   
   # macOS
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   
   # Windows
   ipconfig /flushdns
   ```

2. Check with different DNS servers:
   ```bash
   dig @8.8.8.8 www.horizen-network.com +short
   dig @1.1.1.1 www.horizen-network.com +short
   ```

3. Use online tools:
   - https://www.whatsmydns.net/
   - https://dnschecker.org/

### WWW Not Working

**Problem**: www.horizen-network.com doesn't resolve

**Solutions**:
1. Verify CNAME record exists:
   ```bash
   dig www.horizen-network.com CNAME +short
   ```

2. Check it points to horizen-network.com (without www)

3. Ensure @ (root) record has an A record

4. Wait for propagation (up to 48 hours)

### SSL Certificate Fails

**Problem**: Let's Encrypt cannot verify domain

**Solutions**:
1. Disable Cloudflare proxy (set to "DNS only")
2. Wait 5 minutes for DNS to update
3. Ensure port 80 is open on your server
4. Run SSL setup again: `sudo ./scripts/ssl-setup.sh`
5. Check Cloudflare firewall rules aren't blocking Let's Encrypt

### Mixed Content Errors

**Problem**: Site loads but shows mixed content warnings

**Solutions**:
1. Enable "Always Use HTTPS" in Cloudflare
2. Set SSL mode to "Full" or "Full (strict)"
3. Update hardcoded HTTP URLs to HTTPS in your code
4. Use protocol-relative URLs: `//example.com/resource`

### Proxy Issues

**Problem**: Server logs show Cloudflare IPs instead of visitor IPs

**Solution**:
Enable "Restore Original Visitor IP" in your server:
- Nginx: Add `set_real_ip_from` directives
- Apache: Use `mod_remoteip`

Cloudflare provides visitor IP in headers:
- `CF-Connecting-IP`
- `X-Forwarded-For`

## Monitoring

### DNS Health Monitoring

Set up monitoring to alert on DNS issues:

1. **Cloudflare Analytics**:
   - View DNS query analytics
   - Monitor response times
   - Check for DNSSEC issues

2. **External Monitoring**:
   ```bash
   # Add to cron for regular checks
   */30 * * * * /path/to/dns/validation-script.sh >> /var/log/dns-check.log 2>&1
   ```

3. **Uptime Monitors**:
   - UptimeRobot (free)
   - Pingdom
   - StatusCake

### Cloudflare Notifications

Configure email alerts for:
- DNS changes
- SSL certificate expiration
- DDoS attacks
- Rate limiting triggers

## Best Practices

1. **Always use CNAME for www**: Easier to manage than A records
2. **Keep "DNS only" during setup**: Enable proxy after SSL works
3. **Document all changes**: Keep a record of DNS modifications
4. **Use low TTL during migration**: 300 seconds (5 minutes)
5. **Raise TTL after stable**: 3600 seconds (1 hour) or 86400 (24 hours)
6. **Enable DNSSEC**: In Cloudflare DNS settings for extra security
7. **Regular backups**: Export DNS records regularly
8. **Test before proxy**: Ensure everything works before enabling Cloudflare proxy

## Quick Reference Commands

```bash
# Verify all DNS records
./dns/validation-script.sh

# Check specific record
dig www.horizen-network.com +short

# Check from Cloudflare's DNS
dig @1.1.1.1 www.horizen-network.com +short

# Trace DNS resolution
dig www.horizen-network.com +trace

# Export Cloudflare DNS records (via API)
curl -X GET "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records" \
     -H "Authorization: Bearer {api_token}"
```

## Additional Resources

- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Cloudflare API Documentation](https://api.cloudflare.com/)
- [DNS Configuration Guide](../docs/DNS_CONFIGURATION.md)
- [SSL Setup Script](../scripts/ssl-setup.sh)
- [Production Quickstart](../PRODUCTION_QUICKSTART.md)

## Support

For Cloudflare-specific issues:
- Cloudflare Community: https://community.cloudflare.com/
- Cloudflare Support: https://support.cloudflare.com/

For Horizen Network deployment issues:
- Check logs: `docker-compose logs nginx`
- Run validation: `./scripts/validate.sh`
- See troubleshooting: `docs/DNS_CONFIGURATION.md`

---

**Last Updated**: 2024-12-16
**Status**: Production Ready
