# DNS Configuration Guide for Horizen Network

## 📖 Overview

This guide provides comprehensive instructions for configuring DNS records for horizen-network.com and all required subdomains. Proper DNS configuration is essential before deploying the Horizen Network infrastructure.

## 🎯 Quick Setup Checklist

Before deploying the Horizen Network, complete these DNS configuration steps:

- [ ] **Domain Ownership**: Ensure you own or control horizen-network.com
- [ ] **Server IP**: Obtain your server's public IP address
- [ ] **DNS Provider Access**: Log in to your DNS provider dashboard
- [ ] **Create A Record**: Point horizen-network.com to your server IP
- [ ] **Create CNAME Records**: Add all required subdomain CNAME records
- [ ] **Verify DNS Propagation**: Use verification tools to confirm DNS is working
- [ ] **Test Resolution**: Run `./dns/scripts/verify-dns.sh` to validate
- [ ] **Configure CAA Records**: (Optional) Authorize Let's Encrypt for SSL
- [ ] **Wait for Propagation**: Allow 1-24 hours for global DNS propagation

## 🌐 Required DNS Records

### Overview

The Horizen Network requires the following DNS configuration:

| Type | Name | Value/Target | TTL | Purpose |
|------|------|--------------|-----|---------|
| A | @ | YOUR_SERVER_IP | 3600 | Main domain |
| CNAME | www | horizen-network.com | 3600 | WWW redirect |
| CNAME | druid | horizen-network.com | 3600 | Apache Druid UI |
| CNAME | geniess | horizen-network.com | 3600 | Geniess AI platform |
| CNAME | entity | horizen-network.com | 3600 | Entity unified AI app |
| CNAME | api | horizen-network.com | 3600 | API endpoint |
| CAA | @ | 0 issue "letsencrypt.org" | 3600 | SSL certificate authority |
| CAA | @ | 0 issuewild "letsencrypt.org" | 3600 | Wildcard SSL authority |

**See [RECORDS.md](RECORDS.md) for detailed record specifications.**

## 📚 Documentation

### Core Documentation
- **[RECORDS.md](RECORDS.md)** - Detailed DNS record specifications and examples
- **[VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md)** - Step-by-step verification process
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[MIGRATION.md](MIGRATION.md)** - Migrating DNS between providers

### Provider-Specific Guides
- **[Cloudflare Setup](providers/cloudflare.md)** - Recommended for performance and security
- **[GoDaddy Setup](providers/godaddy.md)** - Popular domain registrar
- **[Namecheap Setup](providers/namecheap.md)** - Affordable registrar with good DNS
- **[AWS Route 53](providers/route53.md)** - Enterprise AWS DNS service
- **[DigitalOcean DNS](providers/digitalocean.md)** - Simple and fast DNS

## 🛠️ Automation Scripts

### DNS Verification
```bash
# Verify all DNS records
./dns/scripts/verify-dns.sh

# Quick verification (main domain only)
./dns/scripts/verify-dns.sh --quick

# Verbose output with debugging
./dns/scripts/verify-dns.sh --verbose
```

### Cloudflare Automation
```bash
# Set environment variables
export CLOUDFLARE_API_TOKEN="your_token_here"
export CLOUDFLARE_ZONE_ID="your_zone_id"
export SERVER_IP="203.0.113.10"

# Automated Cloudflare setup
./dns/scripts/setup-cloudflare.sh
```

### DNS Monitoring
```bash
# Start DNS monitoring (runs continuously)
./dns/scripts/monitor-dns.sh

# Monitor with email alerts
./dns/scripts/monitor-dns.sh --email admin@horizen-network.com
```

### Export DNS Records
```bash
# Export to all formats
./dns/scripts/export-records.sh

# Export to specific format
./dns/scripts/export-records.sh --format json
./dns/scripts/export-records.sh --format csv
./dns/scripts/export-records.sh --format terraform
./dns/scripts/export-records.sh --format bind
```

### Update IP Address
```bash
# Update DNS records with new IP
./dns/scripts/update-ip.sh 203.0.113.10

# Update specific provider
./dns/scripts/update-ip.sh 203.0.113.10 --provider cloudflare
```

## 🚀 Quick Start Guide

### Step 1: Get Your Server IP

```bash
# Find your server's public IP address
curl -4 ifconfig.me
```

### Step 2: Configure DNS Records

**Option A: Manual Configuration**
1. Log in to your DNS provider
2. Navigate to DNS management for horizen-network.com
3. Add the required records from the table above
4. Wait for DNS propagation (1-24 hours)

**Option B: Automated Configuration (Cloudflare)**
```bash
# Set environment variables
export CLOUDFLARE_API_TOKEN="your_token"
export CLOUDFLARE_ZONE_ID="your_zone_id"
export SERVER_IP="your_server_ip"

# Run automated setup
./dns/scripts/setup-cloudflare.sh
```

### Step 3: Verify DNS Configuration

```bash
# Run verification script
./dns/scripts/verify-dns.sh

# All checks should show green ✓
```

### Step 4: Wait for Global Propagation

DNS changes can take time to propagate worldwide:
- **Minimum**: 5-10 minutes
- **Typical**: 1-2 hours  
- **Maximum**: 24-48 hours

Check propagation status at: https://www.whatsmydns.net/

### Step 5: Proceed with Deployment

Once DNS is verified, you can deploy the infrastructure:
```bash
./scripts/deploy.sh prod
```

## 🔍 Verification Commands

### Check Individual Records

```bash
# Check main domain A record
dig horizen-network.com A +short

# Check subdomain CNAME records
dig www.horizen-network.com CNAME +short
dig druid.horizen-network.com CNAME +short
dig geniess.horizen-network.com CNAME +short
dig entity.horizen-network.com CNAME +short
dig api.horizen-network.com CNAME +short

# Check CAA records
dig horizen-network.com CAA +short
```

### Check from Multiple DNS Servers

```bash
# Google DNS
dig @8.8.8.8 horizen-network.com +short

# Cloudflare DNS
dig @1.1.1.1 horizen-network.com +short

# Quad9 DNS
dig @9.9.9.9 horizen-network.com +short
```

### Online Verification Tools

- **DNS Checker**: https://dnschecker.org/
- **What's My DNS**: https://www.whatsmydns.net/
- **DNS Propagation**: https://www.dnswatch.info/
- **MxToolbox**: https://mxtoolbox.com/DNSLookup.aspx

## 🔐 SSL Certificate Considerations

### CAA Records (Recommended)

CAA records specify which Certificate Authorities can issue SSL certificates for your domain:

```
Type: CAA
Name: @
Value: 0 issue "letsencrypt.org"
TTL: 3600
```

This allows Let's Encrypt to issue certificates while blocking unauthorized CAs.

### DNS Validation for SSL

Let's Encrypt uses DNS to verify domain ownership. Ensure:
1. ✅ A record points to your server
2. ✅ Port 80 is accessible
3. ✅ Nginx is running
4. ✅ No firewall blocking

Then run:
```bash
sudo ./scripts/ssl-setup.sh
```

## 📊 DNS Provider Recommendations

### Cloudflare (Recommended)
**Pros:**
- Free CDN and DDoS protection
- Automatic SSL certificates
- Fast global DNS
- Advanced security features
- Built-in analytics

**Cons:**
- Requires nameserver change
- Some features need paid plans

**Best for**: Production deployments, high-traffic sites

### AWS Route 53
**Pros:**
- Enterprise-grade reliability
- Programmatic API access
- Health checks and routing policies
- Integrates with AWS services

**Cons:**
- Not free (pay per query)
- Steeper learning curve

**Best for**: AWS-hosted infrastructure, complex routing

### DigitalOcean DNS
**Pros:**
- Completely free
- Simple interface
- Fast propagation
- Good documentation

**Cons:**
- Fewer advanced features
- No CDN included

**Best for**: Simple deployments, DigitalOcean users

### GoDaddy / Namecheap
**Pros:**
- Often included with domain registration
- Familiar interface
- Good support

**Cons:**
- Slower propagation
- Limited advanced features
- No CDN

**Best for**: Beginners, simple websites

## 🧪 Testing DNS Configuration

### Test Script

Use the automated test script:
```bash
./dns/tests/test-dns-resolution.sh
```

This script tests:
- ✅ DNS resolution from multiple locations
- ✅ SSL certificate readiness
- ✅ Response times
- ✅ Correct routing

### Manual Testing

```bash
# Test main domain
curl -I http://horizen-network.com

# Test subdomains
curl -I http://druid.horizen-network.com
curl -I http://geniess.horizen-network.com
curl -I http://entity.horizen-network.com
curl -I http://api.horizen-network.com
```

## 🔧 Infrastructure as Code

### Terraform Configuration

Use Terraform to manage DNS as code:

```hcl
# dns/templates/cloudflare-terraform.tf
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Apply with:
terraform init
terraform plan
terraform apply
```

### JSON Configuration

Machine-readable DNS records for automation:
```json
{
  "domain": "horizen-network.com",
  "records": [...]
}
```

See [templates/records.json](templates/records.json) for full configuration.

## 📈 Monitoring and Alerts

### Continuous Monitoring

Set up continuous DNS monitoring:
```bash
# Run in background
nohup ./dns/scripts/monitor-dns.sh &

# Or add to crontab
*/5 * * * * cd /path/to/repo && ./dns/scripts/monitor-dns.sh >> /var/log/dns-monitor.log 2>&1
```

### Health Checks

DNS health checks are integrated into the main health check script:
```bash
./scripts/health-check.sh
```

## 🆘 Getting Help

If you encounter issues with DNS configuration:

1. **Check the troubleshooting guide**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Verify with the checklist**: [VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md)
3. **Review provider documentation**: [providers/](providers/)
4. **Run the verification script**: `./dns/scripts/verify-dns.sh --verbose`
5. **Check DNS propagation**: https://www.whatsmydns.net/
6. **Review provider logs**: Check your DNS provider's dashboard
7. **Create a GitHub issue**: Include output from verification script

## 📖 Additional Resources

### DNS Basics
- [Cloudflare DNS Learning Center](https://www.cloudflare.com/learning/dns/what-is-dns/)
- [AWS Route 53 Documentation](https://docs.aws.amazon.com/route53/)
- [DNS RFC Standards](https://www.ietf.org/rfc/rfc1035.txt)

### SSL/TLS
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [SSL Labs Test](https://www.ssllabs.com/ssltest/)
- [CAA Record Generator](https://sslmate.com/caa/)

### Tools
- [dig Command Tutorial](https://www.digwebinterface.com/)
- [nslookup Guide](https://www.nslookup.io/learning/)
- [DNS Propagation Checker](https://www.whatsmydns.net/)

## 🔄 Next Steps

After DNS configuration:

1. ✅ Verify DNS with `./dns/scripts/verify-dns.sh`
2. ✅ Wait for global propagation (check https://www.whatsmydns.net/)
3. ✅ Deploy infrastructure with `./scripts/deploy.sh prod`
4. ✅ Setup SSL certificates with `sudo ./scripts/ssl-setup.sh`
5. ✅ Run health checks with `./scripts/health-check.sh`
6. ✅ Access your services via configured domains

## 📝 Notes

- **TTL Values**: Start with low TTL (300) during setup, increase to 3600 once stable
- **Propagation Time**: Can vary by location and ISP DNS cache settings
- **CAA Records**: Optional but recommended for security
- **DNSSEC**: Advanced security feature, configure if supported by provider
- **IPv6**: Add AAAA records if your server has IPv6 connectivity

---

**Built with ❤️ for the Horizen Network**

For the main deployment guide, see [../docs/DEPLOYMENT_GUIDE.md](../docs/DEPLOYMENT_GUIDE.md)
