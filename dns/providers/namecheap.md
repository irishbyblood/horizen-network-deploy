# Namecheap DNS Setup Guide

## 📖 Overview

Namecheap is a popular domain registrar offering affordable domains with built-in DNS management. This guide shows how to configure DNS for Horizen Network.

## 🚀 Setup Instructions

### Step 1: Access Advanced DNS

1. Log in to https://www.namecheap.com/
2. Go to "Domain List" in left sidebar
3. Click "Manage" next to horizen-network.com
4. Click "Advanced DNS" tab

### Step 2: Configure DNS Records

#### Add A Record for Main Domain

1. Find "HOST RECORDS" section
2. Click "Add New Record"
3. Configure:
   ```
   Type: A Record
   Host: @
   Value: YOUR_SERVER_IP
   TTL: Automatic
   ```
4. Click the green checkmark to save

#### Add CNAME Records

Add these CNAME records (click "Add New Record" for each):

```
Type: CNAME Record
Host: www
Target: horizen-network.com.
TTL: Automatic

Type: CNAME Record
Host: druid
Target: horizen-network.com.
TTL: Automatic

Type: CNAME Record
Host: geniess
Target: horizen-network.com.
TTL: Automatic

Type: CNAME Record
Host: entity
Target: horizen-network.com.
TTL: Automatic

Type: CNAME Record
Host: api
Target: horizen-network.com.
TTL: Automatic
```

**Important**: Include the trailing dot (.) in target value.

#### Add CAA Records (Optional)

```
Type: CAA Record
Host: @
Tag: issue
Value: letsencrypt.org
TTL: Automatic
```

### Step 3: Remove Default Records (Optional)

Namecheap adds default parking page records. Remove these if present:
- URL Redirect Records (if you don't need them)
- Default A records pointing to parking servers

## ✅ Verification

```bash
# Check DNS
dig horizen-network.com A +short
dig www.horizen-network.com CNAME +short
dig druid.horizen-network.com CNAME +short
```

**Propagation Time**: 30 minutes to 24 hours

## 🔧 Using Custom Nameservers

To use external DNS (Cloudflare, AWS, etc.):

1. In "Domain" tab, find "NAMESERVERS" section
2. Select "Custom DNS"
3. Enter nameservers:
   ```
   ns1.cloudflare.com
   ns2.cloudflare.com
   ```
4. Click the green checkmark

## 🐛 Common Issues

### Issue: Must Include Trailing Dot

**Symptoms**: CNAME not resolving correctly

**Solution**: Add trailing dot to target:
- ❌ Wrong: `horizen-network.com`
- ✅ Right: `horizen-network.com.`

### Issue: "Host Record Already Exists"

**Symptoms**: Can't add record

**Solution**:
1. Check for duplicate records
2. Edit existing record instead
3. Delete conflicting record first

## 💡 Tips

- Use "Automatic" TTL for simplicity
- Enable "Email Forwarding" if needed (separate section)
- Enable "DNSSEC" for security (in Advanced DNS)
- Save changes after each record addition

## 📖 Resources

- **Namecheap DNS Guide**: https://www.namecheap.com/support/knowledgebase/article.aspx/319/2237/how-can-i-set-up-an-a-address-record-for-my-domain
- **Support**: https://www.namecheap.com/support/
- **Live Chat**: Available 24/7

## ✅ Checklist

- [ ] Logged into Namecheap
- [ ] Accessed Advanced DNS tab
- [ ] Added A record for @
- [ ] Added CNAME records (with trailing dots)
- [ ] Removed default parking records
- [ ] Added CAA records
- [ ] Saved all changes
- [ ] Verified with dig commands
- [ ] Checked propagation

---

For more help, see [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
