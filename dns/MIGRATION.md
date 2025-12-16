# DNS Provider Migration Guide

Guide for migrating DNS between providers with minimal downtime for Horizen Network.

## 📖 Overview

This guide covers migrating DNS from one provider to another while maintaining uptime and avoiding service disruption.

## ⚠️ Before You Start

**Important Considerations:**

- DNS changes take time to propagate (up to 48 hours)
- Plan migration during low-traffic period
- Have rollback plan ready
- Test thoroughly before switching production

**Prerequisites:**

- Access to current DNS provider
- Account created at new DNS provider
- Current DNS records documented
- Backup of existing configuration

## 🎯 Migration Strategies

### Strategy 1: Parallel Migration (Recommended)

**Best for:** Production systems requiring zero downtime

**Steps:**
1. Set up records at new provider
2. Lower TTL on old provider
3. Test new provider thoroughly
4. Switch nameservers
5. Monitor for issues
6. Raise TTL after stable

**Downtime:** None (if done correctly)  
**Risk:** Low  
**Duration:** 48-72 hours total

### Strategy 2: Quick Migration

**Best for:** Development/staging or low-traffic sites

**Steps:**
1. Export records from old provider
2. Import to new provider
3. Switch nameservers immediately
4. Wait for propagation

**Downtime:** Possible for some users  
**Risk:** Medium  
**Duration:** 24-48 hours

### Strategy 3: Gradual Migration

**Best for:** Complex setups with many records

**Steps:**
1. Migrate records in phases
2. Test each phase
3. Switch nameservers for tested records
4. Complete remaining records

**Downtime:** Minimal  
**Risk:** Low  
**Duration:** 1-2 weeks

## 🚀 Step-by-Step Migration Process

### Phase 1: Preparation (24-48 hours before)

#### Step 1: Document Current Configuration

```bash
# Export current DNS records
./dns/scripts/export-records.sh

# Manual backup via dig
dig horizen-network.com ANY > dns-backup-$(date +%Y%m%d).txt

# Screenshot DNS provider dashboard
```

#### Step 2: Lower TTL Values

**Current Provider:**
1. Log in to current DNS provider
2. Find all DNS records
3. Change TTL from 3600 (1 hour) to 300 (5 minutes)
4. Save changes
5. **Wait 24-48 hours** for old TTL to expire

**Why?** This ensures DNS changes propagate quickly during migration.

#### Step 3: Set Up New Provider

**Create Account:**
1. Sign up at new DNS provider
2. Add domain to account
3. Note new nameservers provided
4. Don't update nameservers yet!

### Phase 2: Record Migration

#### Step 4: Create Records at New Provider

##### Option A: Manual Entry

Create these records at new provider:

```
Type: A
Name: @
Value: YOUR_SERVER_IP
TTL: 300

Type: CNAME, Name: www, Value: horizen-network.com, TTL: 300
Type: CNAME, Name: druid, Value: horizen-network.com, TTL: 300
Type: CNAME, Name: geniess, Value: horizen-network.com, TTL: 300
Type: CNAME, Name: entity, Value: horizen-network.com, TTL: 300
Type: CNAME, Name: api, Value: horizen-network.com, TTL: 300

Type: CAA, Name: @, Value: 0 issue "letsencrypt.org", TTL: 300
Type: CAA, Name: @, Value: 0 issuewild "letsencrypt.org", TTL: 300
```

##### Option B: Automated (Cloudflare)

```bash
# Set environment variables for new provider
export CLOUDFLARE_API_TOKEN="your_new_token"
export CLOUDFLARE_ZONE_ID="your_new_zone_id"
export SERVER_IP="your_server_ip"

# Run automated setup
./dns/scripts/setup-cloudflare.sh
```

##### Option C: Import from File

If new provider supports import:

```bash
# Export from current setup
./dns/scripts/export-records.sh --format bind

# Import zone file at new provider
# (Process varies by provider)
```

#### Step 5: Verify New Provider Records

**Before switching nameservers**, verify records at new provider:

```bash
# Get new provider's nameservers
# Example for Cloudflare: ava.ns.cloudflare.com

# Test directly against new nameservers
dig @ava.ns.cloudflare.com horizen-network.com A +short
dig @ava.ns.cloudflare.com www.horizen-network.com +short
dig @ava.ns.cloudflare.com druid.horizen-network.com +short

# Should return correct IP addresses
```

**All records must work before proceeding!**

### Phase 3: Nameserver Switch

#### Step 6: Update Nameservers

**At Domain Registrar:**

1. Log in to domain registrar (where you bought the domain)
2. Find "Nameservers" or "DNS Settings"
3. Change from old to new nameservers

**Example:**

Old (GoDaddy):
```
ns1.domaincontrol.com
ns2.domaincontrol.com
```

New (Cloudflare):
```
ava.ns.cloudflare.com
ben.ns.cloudflare.com
```

4. Save changes
5. **Note the time** of nameserver update

#### Step 7: Monitor Propagation

```bash
# Check current nameservers
dig NS horizen-network.com +short

# Should eventually show new nameservers
# May take 1-48 hours

# Monitor with script
./dns/scripts/monitor-dns.sh
```

**Check propagation globally:**
- https://www.whatsmydns.net/?t=NS&q=horizen-network.com

### Phase 4: Verification

#### Step 8: Test All Services

```bash
# Run full verification
./dns/scripts/verify-dns.sh

# Test each subdomain
curl -I http://horizen-network.com
curl -I http://www.horizen-network.com
curl -I http://druid.horizen-network.com
curl -I http://geniess.horizen-network.com
curl -I http://entity.horizen-network.com
curl -I http://api.horizen-network.com
```

#### Step 9: Test from Multiple Locations

Use these tools:
- https://dnschecker.org/
- https://www.whatsmydns.net/
- https://www.dnswatch.info/

Check:
- ✅ A records resolve correctly
- ✅ CNAME records work
- ✅ All geographic regions show correct IP
- ✅ Services are accessible

### Phase 5: Stabilization

#### Step 10: Increase TTL

After 24-48 hours of stability:

1. Log in to **new** DNS provider
2. Update all records
3. Change TTL from 300 to 3600
4. Save changes

**Why?** Higher TTL reduces DNS queries and improves performance.

#### Step 11: Decommission Old Provider

**Wait 7 days** after nameserver switch, then:

1. Verify no traffic to old provider
2. Check old provider analytics (if available)
3. Downgrade or cancel old provider account
4. Keep records exported for backup

## 🔄 Provider-Specific Migration Guides

### From GoDaddy to Cloudflare

1. **Export from GoDaddy:**
   - Log in to GoDaddy
   - Domain → Manage DNS
   - Screenshot or manually document records
   - No export feature available

2. **Import to Cloudflare:**
   - Sign up at Cloudflare
   - Add domain
   - Cloudflare scans GoDaddy records automatically
   - Review and confirm imported records

3. **Switch:**
   - Update nameservers at GoDaddy to Cloudflare's
   - Wait for propagation

### From Namecheap to AWS Route 53

1. **Export from Namecheap:**
   - Advanced DNS → Host Records
   - Manually document (no export)

2. **Create Route 53 Hosted Zone:**
   ```bash
   aws route53 create-hosted-zone --name horizen-network.com
   ```

3. **Import records:**
   ```bash
   # Use CLI or console to create records
   aws route53 change-resource-record-sets --hosted-zone-id ZONE_ID --change-batch file://records.json
   ```

4. **Update nameservers** at Namecheap

### From Any Provider to DigitalOcean

1. **Export current records**
2. **Add domain to DigitalOcean:**
   ```bash
   doctl compute domain create horizen-network.com
   ```

3. **Add records:**
   ```bash
   doctl compute domain records create horizen-network.com \
     --record-type A --record-name @ --record-data SERVER_IP
   ```

4. **Update nameservers:**
   ```
   ns1.digitalocean.com
   ns2.digitalocean.com
   ns3.digitalocean.com
   ```

## 🆘 Rollback Plan

If migration fails:

### Immediate Rollback (During Nameserver Switch)

1. **Revert nameservers** to old provider
2. **Wait 5-30 minutes** for propagation
3. **Verify services** working
4. **Investigate issues** before retry

### Post-Migration Rollback

If issues found after migration:

1. **Identify specific problem**
   - DNS resolution issues?
   - Service downtime?
   - SSL certificate problems?

2. **Try to fix at new provider first**
   - Often faster than rolling back

3. **If must rollback:**
   ```bash
   # Update nameservers back to old provider
   # At domain registrar
   ```

4. **Wait for propagation** (1-48 hours)

## ✅ Migration Checklist

### Pre-Migration
- [ ] Current DNS records documented
- [ ] Configuration exported and backed up
- [ ] New DNS provider account created
- [ ] TTL lowered to 300 (24-48 hours before)
- [ ] Migration scheduled during low-traffic period

### During Migration
- [ ] Records created at new provider
- [ ] Records verified against new nameservers
- [ ] All tests pass at new provider
- [ ] Nameservers updated at registrar
- [ ] Time of nameserver change recorded

### Post-Migration
- [ ] DNS propagation monitored
- [ ] All services tested and working
- [ ] Global propagation confirmed
- [ ] Monitoring in place for 24-48 hours
- [ ] TTL increased back to 3600
- [ ] Old provider account reviewed/canceled

## 📊 Expected Timeline

| Phase | Duration | Action Required |
|-------|----------|-----------------|
| Preparation | 24-48 hours | Lower TTL, wait for expiry |
| Record Setup | 1-2 hours | Create records at new provider |
| Verification | 1 hour | Test new provider directly |
| Nameserver Switch | 5 minutes | Update at registrar |
| Propagation | 1-48 hours | Wait and monitor |
| Stabilization | 24-48 hours | Monitor for issues |
| TTL Increase | 5 minutes | Raise TTL to 3600 |
| **Total** | **3-7 days** | End-to-end process |

## 🔧 Testing During Migration

```bash
# Before nameserver switch - test new provider directly
dig @NEW_NAMESERVER horizen-network.com A

# After nameserver switch - test resolution
dig horizen-network.com A +short

# Monitor continuously
watch -n 60 'dig horizen-network.com A +short'

# Check multiple DNS servers
for ns in 8.8.8.8 1.1.1.1 208.67.222.222; do
  echo "DNS $ns:"
  dig @$ns horizen-network.com A +short
done
```

## 💡 Best Practices

1. **Plan Ahead**: Schedule migration well in advance
2. **Low Traffic Period**: Migrate during off-peak hours
3. **Lower TTL Early**: 24-48 hours before migration
4. **Test Thoroughly**: Verify everything works before switching
5. **Monitor Closely**: Watch for issues during and after migration
6. **Keep Backups**: Export configurations before starting
7. **Document Everything**: Keep detailed notes
8. **Gradual Approach**: Don't rush the process
9. **Have Rollback Ready**: Know how to revert if needed
10. **Communicate**: Inform team/users of planned maintenance

## 📚 Additional Resources

- **DNS Migration Checklist**: https://ns1.com/resources/dns-migration-checklist
- **Provider Comparison**: [providers/](providers/)
- **Verification Tool**: `./dns/scripts/verify-dns.sh`
- **Monitoring Tool**: `./dns/scripts/monitor-dns.sh`

---

**Questions?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or [README.md](README.md)
