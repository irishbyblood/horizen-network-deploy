# DNS Configuration Guide

This guide explains how to configure DNS records for the Horizen Network deployment.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [DNS Record Types](#dns-record-types)
- [Configuration Steps](#configuration-steps)
- [Example DNS Records](#example-dns-records)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Overview

Proper DNS configuration is essential for the Horizen Network to be accessible on the internet. This guide covers:

- Main domain (`horizen-network.com`)
- WWW subdomain (`www.horizen-network.com`)
- Druid subdomain (`druid.horizen-network.com`)
- Geniess subdomain (`geniess.horizen-network.com`)

## Prerequisites

Before configuring DNS:

1. **Domain Name**: You must own or control the domain name
2. **Server IP Address**: Know your server's public IP address
3. **DNS Provider Access**: Access to your domain's DNS management panel
4. **Server Running**: Horizen Network infrastructure deployed and running

### Finding Your Server IP

```bash
# Find public IP address
curl -4 ifconfig.me

# Or
curl -4 icanhazip.com

# Or check from server
ip addr show | grep 'inet ' | grep -v '127.0.0.1'
```

## DNS Record Types

### A Record (Address Record)

Maps a domain name to an IPv4 address.

**Use for**:
- Main domain
- Subdomains pointing to the same server

### CNAME Record (Canonical Name)

Maps a domain name to another domain name (alias).

**Use for**:
- WWW subdomain
- Alternative names for services

### AAAA Record (IPv6 Address)

Maps a domain name to an IPv6 address (if you have IPv6).

**Use for**:
- IPv6 connectivity (optional but recommended)

## Configuration Steps

### Step 1: Access DNS Management

Log in to your domain registrar or DNS provider:
- **GoDaddy**: DNS Management
- **Namecheap**: Advanced DNS
- **Cloudflare**: DNS Settings
- **Route 53**: Hosted Zones
- **Google Domains**: DNS Settings

### Step 2: Configure Main Domain

Create an A record for the main domain:

```
Type: A
Name: @ (or leave blank)
Value: YOUR_SERVER_IP
TTL: 3600 (1 hour) or Auto
```

**Example**:
```
Type: A
Name: @
Value: 203.0.113.10
TTL: 3600
```

### Step 3: Configure WWW Subdomain

Option A - Using CNAME (Recommended):
```
Type: CNAME
Name: www
Value: horizen-network.com (or @)
TTL: 3600
```

Option B - Using A Record:
```
Type: A
Name: www
Value: YOUR_SERVER_IP
TTL: 3600
```

### Step 4: Configure Druid Subdomain

```
Type: A
Name: druid
Value: YOUR_SERVER_IP
TTL: 3600
```

### Step 5: Configure Geniess Subdomain

```
Type: A
Name: geniess
Value: YOUR_SERVER_IP (or Geniess server IP if separate)
TTL: 3600
```

### Step 6: Optional - Add IPv6 Records

If your server has IPv6:

```
Type: AAAA
Name: @
Value: YOUR_IPV6_ADDRESS
TTL: 3600

Type: AAAA
Name: druid
Value: YOUR_IPV6_ADDRESS
TTL: 3600

Type: AAAA
Name: geniess
Value: YOUR_IPV6_ADDRESS
TTL: 3600
```

## Example DNS Records

### Complete DNS Configuration Table

| Type | Name | Value | TTL | Description |
|------|------|-------|-----|-------------|
| A | @ | 203.0.113.10 | 3600 | Main domain |
| A | druid | 203.0.113.10 | 3600 | Druid subdomain |
| A | geniess | 203.0.113.10 | 3600 | Geniess subdomain |
| CNAME | www | horizen-network.com | 3600 | WWW subdomain |
| AAAA | @ | 2001:db8::1 | 3600 | IPv6 for main domain (optional) |
| AAAA | druid | 2001:db8::1 | 3600 | IPv6 for Druid (optional) |
| AAAA | geniess | 2001:db8::1 | 3600 | IPv6 for Geniess (optional) |

### Provider-Specific Examples

#### Cloudflare

```
Type    Name     Content          Proxy  TTL
A       @        203.0.113.10     No     Auto
A       druid    203.0.113.10     No     Auto
A       geniess  203.0.113.10     No     Auto
CNAME   www      horizen-network.com  Yes    Auto
```

**Note**: When using Cloudflare:
- Set Proxy to "DNS Only" initially for SSL setup
- Can enable "Proxied" after SSL is configured
- Cloudflare provides automatic SSL if proxied

#### Route 53 (AWS)

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "horizen-network.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "203.0.113.10"}]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "druid.horizen-network.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "203.0.113.10"}]
      }
    }
  ]
}
```

#### DigitalOcean DNS

```
Hostname           Type    Value            TTL
@                  A       203.0.113.10     3600
www                CNAME   @                3600
druid              A       203.0.113.10     3600
geniess            A       203.0.113.10     3600
```

## Verification

### DNS Propagation Time

DNS changes can take time to propagate:
- **Minimum**: 5-10 minutes
- **Typical**: 1-2 hours
- **Maximum**: 24-48 hours (worst case)

Factors affecting propagation:
- TTL value set in DNS records
- ISP DNS caching
- Geographic location

### Verification Commands

#### Check A Records

```bash
# Check main domain
dig horizen-network.com A +short
nslookup horizen-network.com

# Check subdomain
dig druid.horizen-network.com A +short
dig geniess.horizen-network.com A +short
```

Expected output:
```
203.0.113.10
```

#### Check CNAME Records

```bash
dig www.horizen-network.com CNAME +short
```

Expected output:
```
horizen-network.com.
```

#### Check All Records

```bash
dig horizen-network.com ANY
```

#### Check from Different DNS Servers

```bash
# Check using Google DNS
dig @8.8.8.8 horizen-network.com A +short

# Check using Cloudflare DNS
dig @1.1.1.1 horizen-network.com A +short

# Check using Quad9 DNS
dig @9.9.9.9 horizen-network.com A +short
```

### Online DNS Verification Tools

Use these tools to check DNS propagation globally:

1. **DNS Checker**: https://dnschecker.org/
2. **What's My DNS**: https://www.whatsmydns.net/
3. **DNS Propagation Checker**: https://www.dnswatch.info/
4. **MxToolbox**: https://mxtoolbox.com/DNSLookup.aspx

### Test with Browser

Once DNS is propagated:

```bash
# Test main site
curl -I http://horizen-network.com

# Test Druid
curl -I http://druid.horizen-network.com

# Test Geniess
curl -I http://geniess.horizen-network.com
```

## Advanced Configuration

### CAA Records (SSL Certificate Authority Authorization)

To specify which Certificate Authorities can issue certificates:

```
Type: CAA
Name: @
Value: 0 issue "letsencrypt.org"
TTL: 3600
```

### TXT Records for Verification

May be needed for:
- Domain ownership verification
- Email authentication (SPF, DKIM)
- SSL certificate validation

```
Type: TXT
Name: @
Value: "verification-code-here"
TTL: 3600
```

### Wildcard DNS (Advanced)

For catching all subdomains:

```
Type: A
Name: *
Value: YOUR_SERVER_IP
TTL: 3600
```

**Note**: Use with caution, ensure Nginx is configured to handle wildcard domains.

## Troubleshooting

### Issue: DNS Not Resolving

**Symptoms**: Domain doesn't resolve to IP address

**Solutions**:

1. **Wait for propagation**:
   ```bash
   # Check if DNS has propagated
   dig @8.8.8.8 horizen-network.com +short
   ```

2. **Verify DNS records in provider panel**:
   - Check for typos
   - Ensure records are saved
   - Verify correct IP address

3. **Clear local DNS cache**:
   ```bash
   # Linux
   sudo systemd-resolve --flush-caches
   
   # macOS
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   
   # Windows
   ipconfig /flushdns
   ```

### Issue: Subdomain Not Working

**Symptoms**: Main domain works but subdomains don't

**Solutions**:

1. **Verify subdomain records exist**:
   ```bash
   dig druid.horizen-network.com +short
   ```

2. **Check for wildcards or conflicts**:
   ```bash
   dig druid.horizen-network.com ANY
   ```

3. **Ensure Nginx is configured for subdomain**:
   ```bash
   docker-compose exec nginx nginx -t
   cat nginx/conf.d/default.conf | grep server_name
   ```

### Issue: WWW Not Redirecting

**Symptoms**: www subdomain doesn't redirect to main domain

**Solutions**:

1. **Add CNAME record**:
   ```
   Type: CNAME
   Name: www
   Value: horizen-network.com
   ```

2. **Configure Nginx redirect**:
   ```nginx
   server {
       listen 80;
       server_name www.horizen-network.com;
       return 301 $scheme://horizen-network.com$request_uri;
   }
   ```

### Issue: SSL Certificate Fails

**Symptoms**: Let's Encrypt cannot verify domain

**Solutions**:

1. **Ensure DNS is fully propagated**:
   ```bash
   dig horizen-network.com +short
   ```

2. **Verify port 80 is open**:
   ```bash
   sudo netstat -tulpn | grep :80
   ```

3. **Check Nginx is accessible**:
   ```bash
   curl -I http://horizen-network.com
   ```

4. **Retry SSL setup**:
   ```bash
   sudo ./scripts/ssl-setup.sh
   ```

### Issue: Slow DNS Resolution

**Symptoms**: Domain takes long time to resolve

**Solutions**:

1. **Lower TTL temporarily** (before changes):
   ```
   TTL: 300 (5 minutes)
   ```

2. **Use faster DNS servers**:
   ```bash
   # Edit /etc/resolv.conf
   nameserver 8.8.8.8
   nameserver 1.1.1.1
   ```

3. **Check DNS server performance**:
   ```bash
   time dig horizen-network.com
   ```

## Best Practices

1. **Set appropriate TTL values**:
   - During migration: 300 seconds (5 minutes)
   - Normal operation: 3600 seconds (1 hour)
   - Stable production: 86400 seconds (24 hours)

2. **Use CNAME for subdomains when possible**:
   - Easier to manage
   - Single point of IP change

3. **Monitor DNS health**:
   - Regular DNS checks
   - Automated monitoring tools
   - Alert on DNS failures

4. **Document your configuration**:
   - Keep record of all DNS entries
   - Note when changes were made
   - Track TTL values

5. **Plan DNS changes**:
   - Lower TTL before changes
   - Wait for old TTL to expire
   - Make changes during low-traffic periods

## Additional Resources

- [DNS Basics](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [Let's Encrypt DNS Validation](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Nginx Server Names](https://nginx.org/en/docs/http/server_names.html)

## Next Steps

After DNS is configured:

1. [Complete Deployment](DEPLOYMENT_GUIDE.md)
2. [Setup SSL Certificates](../scripts/ssl-setup.sh)
3. [Configure Applications](APPLICATION_SETUP.md)
4. Test all domains and subdomains
5. Monitor DNS health

## Support

For DNS-related issues:
- Check your DNS provider's documentation
- Use online DNS verification tools
- Review Nginx logs: `docker-compose logs nginx`
- Create an issue on GitHub with DNS query results
