# DNS Verification Checklist

Use this checklist to ensure your DNS is properly configured for Horizen Network deployment.

## 📋 Pre-Configuration Checklist

- [ ] **Domain Ownership Confirmed**
  - You own or control horizen-network.com
  - You have access to domain registrar account
  
- [ ] **DNS Provider Selected**
  - Chosen DNS provider (Cloudflare, AWS Route 53, etc.)
  - Have login credentials ready
  
- [ ] **Server Information Gathered**
  - Server public IP address obtained
  - Server is accessible on ports 80 and 443
  - Firewall configured to allow HTTP/HTTPS traffic

## 🔧 DNS Configuration Checklist

### Step 1: Main Domain A Record

- [ ] **Create A Record**
  ```
  Type: A
  Name: @ (or blank)
  Value: YOUR_SERVER_IP
  TTL: 3600
  ```
  
- [ ] **Verify A Record**
  ```bash
  dig horizen-network.com A +short
  # Should return: YOUR_SERVER_IP
  ```

### Step 2: WWW Subdomain

- [ ] **Create CNAME for www**
  ```
  Type: CNAME
  Name: www
  Value: horizen-network.com
  TTL: 3600
  ```
  
- [ ] **Verify www subdomain**
  ```bash
  dig www.horizen-network.com +short
  # Should return: horizen-network.com. or YOUR_SERVER_IP
  ```

### Step 3: Application Subdomains

- [ ] **Create CNAME for druid**
  ```bash
  dig druid.horizen-network.com +short
  ```
  
- [ ] **Create CNAME for geniess**
  ```bash
  dig geniess.horizen-network.com +short
  ```
  
- [ ] **Create CNAME for entity**
  ```bash
  dig entity.horizen-network.com +short
  ```
  
- [ ] **Create CNAME for api**
  ```bash
  dig api.horizen-network.com +short
  ```

### Step 4: CAA Records (Optional but Recommended)

- [ ] **Create CAA for issue**
  ```
  Type: CAA
  Name: @
  Value: 0 issue "letsencrypt.org"
  ```
  
- [ ] **Create CAA for issuewild**
  ```
  Type: CAA
  Name: @
  Value: 0 issuewild "letsencrypt.org"
  ```
  
- [ ] **Verify CAA records**
  ```bash
  dig horizen-network.com CAA +short
  ```

## ✅ Verification Checklist

### Automated Verification

- [ ] **Run DNS verification script**
  ```bash
  ./dns/scripts/verify-dns.sh
  # All checks should pass (green ✓)
  ```
  
- [ ] **Run with verbose output** (if issues found)
  ```bash
  ./dns/scripts/verify-dns.sh --verbose
  ```

### Manual Verification

- [ ] **Check with Google DNS**
  ```bash
  dig @8.8.8.8 horizen-network.com A +short
  ```
  
- [ ] **Check with Cloudflare DNS**
  ```bash
  dig @1.1.1.1 horizen-network.com A +short
  ```
  
- [ ] **Check with OpenDNS**
  ```bash
  dig @208.67.222.222 horizen-network.com A +short
  ```

### Global Propagation Check

- [ ] **Check propagation on whatsmydns.net**
  - Visit: https://www.whatsmydns.net/
  - Enter: horizen-network.com
  - Type: A
  - Verify multiple green checkmarks globally
  
- [ ] **Check all subdomains propagated**
  - www.horizen-network.com
  - druid.horizen-network.com
  - geniess.horizen-network.com
  - entity.horizen-network.com
  - api.horizen-network.com

### Browser Testing

- [ ] **Test main domain in browser**
  ```
  http://horizen-network.com
  ```
  - Should not show "Server not found" error
  - May show Nginx default page (OK if not deployed yet)
  
- [ ] **Test www redirect**
  ```
  http://www.horizen-network.com
  ```
  
- [ ] **Test application subdomains**
  - http://druid.horizen-network.com
  - http://geniess.horizen-network.com
  - http://entity.horizen-network.com
  - http://api.horizen-network.com

## 🕐 Propagation Timing

- [ ] **Initial propagation started** (5-10 minutes after DNS changes)
- [ ] **Partial propagation** (30-60 minutes, some DNS servers updated)
- [ ] **Full propagation** (2-24 hours, all DNS servers updated globally)

**Note**: Don't proceed with deployment until DNS is at least partially propagated (30+ minutes).

## 🔒 SSL Readiness Checklist

Before requesting SSL certificates:

- [ ] **DNS fully propagated**
  - All dig commands return correct values
  - whatsmydns.net shows green globally
  
- [ ] **Port 80 accessible**
  ```bash
  curl -I http://horizen-network.com
  ```
  
- [ ] **Port 443 accessible**
  ```bash
  telnet horizen-network.com 443
  ```
  
- [ ] **CAA records allow Let's Encrypt**
  ```bash
  dig horizen-network.com CAA | grep letsencrypt
  ```
  
- [ ] **No firewall blocking**
  - Verify firewall rules allow 80/443
  - Check cloud provider security groups
  
- [ ] **Server is deployed and running**
  ```bash
  ./scripts/health-check.sh
  ```

## 📝 Documentation Checklist

- [ ] **Document your configuration**
  - Save a copy of all DNS records
  - Note when changes were made
  - Record TTL values used
  
- [ ] **Export DNS configuration**
  ```bash
  ./dns/scripts/export-records.sh
  ```
  
- [ ] **Save exported files** to secure location
  - JSON, CSV, Terraform, BIND formats available
  - Keep for backup and disaster recovery

## 🚀 Deployment Readiness

Once all above items are checked:

- [ ] **Final DNS verification**
  ```bash
  ./dns/scripts/verify-dns.sh
  ```
  
- [ ] **All checks pass (no red ✗ marks)**

- [ ] **Global propagation confirmed**
  - https://www.whatsmydns.net/ shows all green
  
- [ ] **Proceed with deployment**
  ```bash
  ./scripts/deploy.sh prod
  ```
  
- [ ] **Setup SSL certificates**
  ```bash
  sudo ./scripts/ssl-setup.sh
  ```
  
- [ ] **Verify HTTPS working**
  ```bash
  curl -I https://horizen-network.com
  ```

## 🐛 Troubleshooting Quick Reference

If verification fails, check:

1. **DNS records exist** - Log in to provider dashboard
2. **Correct IP address** - Verify server IP hasn't changed
3. **TTL expired** - Wait for old TTL period
4. **Nameservers correct** - For external DNS providers
5. **No typos** - Double-check domain spelling
6. **Provider propagation** - Some providers slower than others

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## ✅ Success Criteria

DNS is ready when:

✅ All dig commands return expected values  
✅ whatsmydns.net shows global propagation  
✅ Browser can reach domain (even if showing default page)  
✅ All subdomains resolve correctly  
✅ CAA records present (optional but recommended)  
✅ Verification script passes all checks  

**You can now proceed with deployment!** 🎉

---

**Estimated Time**: 30 minutes to 24 hours depending on propagation speed

**Next Steps**: [Deploy Infrastructure](../docs/DEPLOYMENT_GUIDE.md) → [Setup SSL](../scripts/ssl-setup.sh)
