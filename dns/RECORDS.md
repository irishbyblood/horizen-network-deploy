# DNS Records Specification

This document provides detailed specifications for all DNS records required for the Horizen Network infrastructure.

## 📋 Complete DNS Records Table

| Type | Name | Value/Target | TTL | Priority | Purpose | Notes |
|------|------|--------------|-----|----------|---------|-------|
| A | @ | YOUR_SERVER_IP | 3600 | - | Main domain | Replace YOUR_SERVER_IP with actual IP |
| CNAME | www | horizen-network.com | 3600 | - | WWW subdomain | Redirects to main domain |
| CNAME | druid | horizen-network.com | 3600 | - | Apache Druid UI | Analytics interface |
| CNAME | geniess | horizen-network.com | 3600 | - | Geniess platform | AI intelligence platform |
| CNAME | entity | horizen-network.com | 3600 | - | Entity application | Unified AI web app |
| CNAME | api | horizen-network.com | 3600 | - | API endpoint | Unified REST API |
| CAA | @ | 0 issue "letsencrypt.org" | 3600 | - | SSL authorization | Allows Let's Encrypt certs |
| CAA | @ | 0 issuewild "letsencrypt.org" | 3600 | - | Wildcard SSL | Allows wildcard certificates |
| TXT | @ | v=spf1 -all | 3600 | - | Email policy | Prevent email spoofing (optional) |

## 📝 Record Type Descriptions

### A Record (Address Record)

**Purpose**: Maps domain name to IPv4 address

**Format**:
```
Type: A
Name: @ (or blank for root domain)
Value: 203.0.113.10
TTL: 3600
```

**Example Configuration**:
```
horizen-network.com.  3600  IN  A  203.0.113.10
```

**When to Use**:
- Main domain (required)
- Direct subdomain IP mapping (alternative to CNAME)

**Notes**:
- Must point to a public IPv4 address
- Change this when server IP changes
- Use lower TTL (300) during migration

### CNAME Record (Canonical Name)

**Purpose**: Creates an alias pointing to another domain name

**Format**:
```
Type: CNAME
Name: www
Value: horizen-network.com (or @)
TTL: 3600
```

**Example Configuration**:
```
www.horizen-network.com.     3600  IN  CNAME  horizen-network.com.
druid.horizen-network.com.   3600  IN  CNAME  horizen-network.com.
geniess.horizen-network.com. 3600  IN  CNAME  horizen-network.com.
entity.horizen-network.com.  3600  IN  CNAME  horizen-network.com.
api.horizen-network.com.     3600  IN  CNAME  horizen-network.com.
```

**When to Use**:
- All subdomains (www, druid, geniess, entity, api)
- Easier management (change IP once in A record)

**Notes**:
- Cannot be used for root domain (@)
- Must point to domain, not IP
- Follow the dot (.) if required by provider

### CAA Record (Certificate Authority Authorization)

**Purpose**: Specifies which CAs can issue SSL certificates

**Format**:
```
Type: CAA
Name: @ (or blank)
Flags: 0
Tag: issue
Value: letsencrypt.org
TTL: 3600
```

**Example Configuration**:
```
horizen-network.com.  3600  IN  CAA  0 issue "letsencrypt.org"
horizen-network.com.  3600  IN  CAA  0 issuewild "letsencrypt.org"
```

**When to Use**:
- When using Let's Encrypt for SSL (recommended)
- To prevent unauthorized certificate issuance

**CAA Record Types**:
- `issue`: Authorize specific CA for standard certificates
- `issuewild`: Authorize specific CA for wildcard certificates
- `iodef`: Specify URL for violation reports (optional)

**Notes**:
- Not all DNS providers support CAA records
- Optional but highly recommended for security
- Check provider documentation for format

### TXT Record (Text Record)

**Purpose**: Stores arbitrary text data, used for verification and policies

**Format**:
```
Type: TXT
Name: @
Value: "v=spf1 -all"
TTL: 3600
```

**Example Configuration**:
```
horizen-network.com.  3600  IN  TXT  "v=spf1 -all"
```

**When to Use**:
- SPF email policy (if not sending email)
- Domain verification (Google, etc.)
- DKIM records (if using email)
- Domain ownership verification

**Notes**:
- Value must be quoted
- Multiple TXT records allowed
- `-all` in SPF means "no servers authorized"

## 🎯 Record Priority by Importance

### Critical (Must Have)

1. **A Record for Main Domain**
   - Without this, nothing works
   - Points horizen-network.com to server IP

2. **CNAME Records for Subdomains**
   - Required for application access
   - druid, geniess, entity, api, www

### Recommended (Should Have)

3. **CAA Records**
   - Enhances security
   - Prevents unauthorized SSL certificates
   - Required by some certificate authorities

### Optional (Nice to Have)

4. **TXT Records**
   - SPF record (if not using email)
   - Domain verification records
   - Additional metadata

## 📊 Provider-Specific Format Examples

### Cloudflare Format

```
Type    Name     Content                      Proxy  TTL
A       @        203.0.113.10                 No     Auto
CNAME   www      horizen-network.com          Yes    Auto
CNAME   druid    horizen-network.com          No     Auto
CNAME   geniess  horizen-network.com          No     Auto
CNAME   entity   horizen-network.com          No     Auto
CNAME   api      horizen-network.com          No     Auto
CAA     @        0 issue "letsencrypt.org"    -      Auto
CAA     @        0 issuewild "letsencrypt.org" -     Auto
```

**Notes**:
- Proxy = "No" for SSL setup, can enable later
- TTL = "Auto" is recommended (Cloudflare manages)

### AWS Route 53 Format

```json
{
  "Name": "horizen-network.com",
  "Type": "A",
  "TTL": 300,
  "ResourceRecords": [
    {"Value": "203.0.113.10"}
  ]
}

{
  "Name": "www.horizen-network.com",
  "Type": "CNAME",
  "TTL": 300,
  "ResourceRecords": [
    {"Value": "horizen-network.com"}
  ]
}
```

### GoDaddy Format

```
Type    Host     Points to              TTL
A       @        203.0.113.10          1 Hour
CNAME   www      @                     1 Hour
CNAME   druid    @                     1 Hour
CNAME   geniess  @                     1 Hour
CNAME   entity   @                     1 Hour
CNAME   api      @                     1 Hour
```

### Namecheap Format

```
Type          Host     Value                  TTL
A Record      @        203.0.113.10          Automatic
CNAME Record  www      horizen-network.com.  Automatic
CNAME Record  druid    horizen-network.com.  Automatic
CNAME Record  geniess  horizen-network.com.  Automatic
CNAME Record  entity   horizen-network.com.  Automatic
CNAME Record  api      horizen-network.com.  Automatic
```

### DigitalOcean Format

```
Type    Hostname  Value                      TTL
A       @         203.0.113.10              3600
CNAME   www       @                         3600
CNAME   druid     @                         3600
CNAME   geniess   @                         3600
CNAME   entity    @                         3600
CNAME   api       @                         3600
```

## 🔧 TTL (Time To Live) Guidelines

### TTL Values Explained

TTL specifies how long DNS resolvers cache your records before querying again.

| TTL Value | Duration | Use Case |
|-----------|----------|----------|
| 60 | 1 minute | Active testing/migration |
| 300 | 5 minutes | Initial setup, changes expected |
| 1800 | 30 minutes | Frequent updates |
| 3600 | 1 hour | Standard production (recommended) |
| 7200 | 2 hours | Stable production |
| 86400 | 24 hours | Very stable, rarely changes |

### Recommended TTL Strategy

**Phase 1: Initial Setup**
```
TTL: 300 (5 minutes)
- Quick propagation
- Easy to fix mistakes
- Can iterate rapidly
```

**Phase 2: Testing & Verification**
```
TTL: 1800 (30 minutes)
- Balance between speed and cache
- Testing phase
- Minor adjustments
```

**Phase 3: Production Stable**
```
TTL: 3600 (1 hour)
- Standard production value
- Good balance
- Recommended for most use cases
```

**Phase 4: Highly Stable**
```
TTL: 86400 (24 hours)
- Rarely change DNS
- Reduce DNS queries
- Lower costs (AWS Route 53)
```

### Changing TTL Best Practice

When planning DNS changes:

1. **24-48 hours before**: Lower TTL to 300
2. **Wait**: Old TTL to expire
3. **Make changes**: Update records
4. **Verify**: Confirm propagation
5. **Increase TTL**: Back to 3600 after stable

## 🌐 IPv6 Support (AAAA Records)

If your server has IPv6 connectivity, add AAAA records:

```
Type    Name     Value                                TTL
AAAA    @        2001:db8::1                         3600
AAAA    druid    2001:db8::1                         3600
AAAA    geniess  2001:db8::1                         3600
AAAA    entity   2001:db8::1                         3600
AAAA    api      2001:db8::1                         3600
```

**Notes**:
- Replace `2001:db8::1` with your actual IPv6 address
- Find IPv6: `curl -6 ifconfig.me`
- Optional but recommended for future-proofing
- Nginx must listen on IPv6: `listen [::]:80;`

## 🔒 DNSSEC (Advanced)

DNSSEC adds cryptographic signatures to DNS records:

**Benefits**:
- Prevents DNS spoofing
- Ensures data integrity
- Industry best practice

**Requirements**:
- DNS provider must support DNSSEC
- Domain registrar must support DS records
- More complex to manage

**Setup** (if supported):
1. Enable DNSSEC in DNS provider
2. Get DS records from provider
3. Add DS records at registrar
4. Verify with: `dig horizen-network.com +dnssec`

**Providers with DNSSEC Support**:
- ✅ Cloudflare (free)
- ✅ AWS Route 53 (included)
- ✅ Google Cloud DNS (included)
- ❌ GoDaddy (limited support)
- ❌ Namecheap (limited support)

## 📋 Validation Checklist

After adding DNS records, verify each:

### Main Domain (A Record)
```bash
dig horizen-network.com A +short
# Expected: 203.0.113.10
```

### WWW Subdomain (CNAME)
```bash
dig www.horizen-network.com CNAME +short
# Expected: horizen-network.com.
```

### Application Subdomains (CNAME)
```bash
dig druid.horizen-network.com CNAME +short
dig geniess.horizen-network.com CNAME +short
dig entity.horizen-network.com CNAME +short
dig api.horizen-network.com CNAME +short
# Expected: horizen-network.com.
```

### CAA Records
```bash
dig horizen-network.com CAA +short
# Expected: 0 issue "letsencrypt.org"
#           0 issuewild "letsencrypt.org"
```

### Automated Verification
```bash
./dns/scripts/verify-dns.sh
```

## 🚨 Common Mistakes to Avoid

### 1. Forgetting the Trailing Dot
**Wrong**: `CNAME www horizen-network.com`  
**Right**: `CNAME www horizen-network.com.`

Some providers add it automatically, others require it.

### 2. Using CNAME for Root Domain
**Wrong**: `CNAME @ someotherdomain.com`  
**Right**: `A @ 203.0.113.10`

CNAME cannot be used for root (@) domain per RFC.

### 3. Wrong TTL During Migration
**Wrong**: High TTL (86400) during changes  
**Right**: Low TTL (300) before and during changes

Lower TTL before making changes!

### 4. Missing CAA Records
**Risk**: Any CA can issue certificates  
**Solution**: Add CAA records for Let's Encrypt

### 5. Not Waiting for Propagation
**Problem**: Testing immediately after changes  
**Solution**: Wait 5-60 minutes, check https://whatsmydns.net/

### 6. Incorrect IP Format
**Wrong**: `http://203.0.113.10` or `203.0.113.10/24`  
**Right**: `203.0.113.10`

Just the IP address, no protocol or CIDR.

## 📖 Export Formats

### BIND Zone File Format
```
$ORIGIN horizen-network.com.
$TTL 3600

@       IN  SOA  ns1.horizen-network.com. admin.horizen-network.com. (
                2024121601  ; Serial
                7200        ; Refresh
                3600        ; Retry
                1209600     ; Expire
                3600 )      ; Minimum TTL

@       IN  A        203.0.113.10
www     IN  CNAME    horizen-network.com.
druid   IN  CNAME    horizen-network.com.
geniess IN  CNAME    horizen-network.com.
entity  IN  CNAME    horizen-network.com.
api     IN  CNAME    horizen-network.com.
@       IN  CAA      0 issue "letsencrypt.org"
@       IN  CAA      0 issuewild "letsencrypt.org"
```

### JSON Format
```json
{
  "domain": "horizen-network.com",
  "ttl": 3600,
  "records": [
    {
      "type": "A",
      "name": "@",
      "value": "203.0.113.10",
      "ttl": 3600
    },
    {
      "type": "CNAME",
      "name": "www",
      "value": "horizen-network.com",
      "ttl": 3600
    }
  ]
}
```

See [templates/](templates/) for complete export formats.

## 🔗 Related Documentation

- [README.md](README.md) - Main DNS configuration guide
- [providers/](providers/) - Provider-specific setup guides
- [scripts/verify-dns.sh](scripts/verify-dns.sh) - Automated verification
- [VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md) - Step-by-step checklist
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

---

**Note**: Replace `YOUR_SERVER_IP` and `203.0.113.10` with your actual server IP address.

For questions or issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
