# AWS Route 53 DNS Setup Guide

## 📖 Overview

AWS Route 53 is Amazon's highly available and scalable DNS service. It's ideal for enterprise deployments and provides programmatic access via AWS CLI and API.

## 🚀 Setup Instructions

### Prerequisites

- AWS Account
- AWS CLI installed and configured
- Domain registered (in Route 53 or external registrar)

### Step 1: Create Hosted Zone

#### Via AWS Console

1. Go to https://console.aws.amazon.com/route53/
2. Click "Hosted zones" in left sidebar
3. Click "Create hosted zone"
4. Configure:
   ```
   Domain name: horizen-network.com
   Type: Public hosted zone
   ```
5. Click "Create hosted zone"
6. **Note the nameservers** provided (4 NS records)

#### Via AWS CLI

```bash
aws route53 create-hosted-zone \
  --name horizen-network.com \
  --caller-reference "horizen-$(date +%s)"
```

### Step 2: Update Nameservers at Registrar

If domain is registered elsewhere:

1. Get nameservers from hosted zone (e.g.):
   ```
   ns-1234.awsdns-00.com
   ns-5678.awsdns-01.net
   ns-9012.awsdns-02.org
   ns-3456.awsdns-03.co.uk
   ```
2. Update nameservers at your registrar
3. Wait for propagation (up to 48 hours)

### Step 3: Create DNS Records

#### Via AWS Console

1. Click on your hosted zone
2. Click "Create record"
3. Create each record:

**A Record for Main Domain:**
```
Record name: (leave blank for root)
Record type: A
Value: YOUR_SERVER_IP
TTL: 300 seconds
Routing policy: Simple routing
```

**CNAME Records:**
```
Record name: www
Record type: CNAME
Value: horizen-network.com
TTL: 300 seconds
```

Repeat for: druid, geniess, entity, api

#### Via AWS CLI

Create a JSON file `dns-records.json`:

```json
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "horizen-network.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "203.0.113.10"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.horizen-network.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "horizen-network.com"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "druid.horizen-network.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "horizen-network.com"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "geniess.horizen-network.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "horizen-network.com"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "entity.horizen-network.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "horizen-network.com"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.horizen-network.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "horizen-network.com"
          }
        ]
      }
    },
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "horizen-network.com",
        "Type": "CAA",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "0 issue \"letsencrypt.org\""
          }
        ]
      }
    }
  ]
}
```

Apply the changes:

```bash
# Get hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name horizen-network.com \
  --query "HostedZones[0].Id" \
  --output text | cut -d'/' -f3)

# Apply DNS records
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file://dns-records.json
```

### Step 4: Setup Health Checks (Optional)

Create health check for monitoring:

```bash
aws route53 create-health-check \
  --health-check-config \
    IPAddress=203.0.113.10,\
    Port=80,\
    Type=HTTP,\
    ResourcePath=/health,\
    RequestInterval=30,\
    FailureThreshold=3
```

## ✅ Verification

```bash
# Get nameservers
aws route53 get-hosted-zone --id $ZONE_ID

# List all records
aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID

# Test DNS resolution
dig horizen-network.com A +short
dig @ns-1234.awsdns-00.com horizen-network.com A +short
```

## 🔧 Advanced Features

### Traffic Policies

Create sophisticated routing:
- Weighted routing
- Latency-based routing
- Geolocation routing
- Failover routing

### DNSSEC

Enable DNSSEC for security:

```bash
aws route53 enable-hosted-zone-dnssec \
  --hosted-zone-id $ZONE_ID
```

### Query Logging

Enable query logging to CloudWatch:

```bash
aws route53 create-query-logging-config \
  --hosted-zone-id $ZONE_ID \
  --cloud-watch-logs-log-group-arn arn:aws:logs:REGION:ACCOUNT:log-group:/aws/route53/horizen-network.com
```

## 💰 Pricing

Route 53 pricing (as of 2024):
- **Hosted Zone**: $0.50/month per zone
- **Standard Queries**: $0.40 per million queries
- **Health Checks**: $0.50/month per check
- **Traffic Flow**: $50/month per policy record

## 🔄 Automation with Terraform

```hcl
# route53.tf
resource "aws_route53_zone" "main" {
  name = "horizen-network.com"
}

resource "aws_route53_record" "main" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "horizen-network.com"
  type    = "A"
  ttl     = 300
  records = [var.server_ip]
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www"
  type    = "CNAME"
  ttl     = 300
  records = ["horizen-network.com"]
}

# Output nameservers
output "nameservers" {
  value = aws_route53_zone.main.name_servers
}
```

Apply:
```bash
terraform init
terraform plan
terraform apply
```

## 🐛 Common Issues

### Issue: High Latency

**Solution**: 
- Use Route 53 latency-based routing
- Configure health checks
- Use Route 53 Traffic Flow

### Issue: Costly Queries

**Solution**:
- Increase TTL values (reduce queries)
- Use CloudFront (includes Route 53 queries)
- Monitor with CloudWatch

## 📖 Resources

- **Route 53 Documentation**: https://docs.aws.amazon.com/route53/
- **CLI Reference**: https://docs.aws.amazon.com/cli/latest/reference/route53/
- **Pricing**: https://aws.amazon.com/route53/pricing/
- **Best Practices**: https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/best-practices-dns.html

## ✅ Checklist

- [ ] AWS account created
- [ ] Hosted zone created
- [ ] Nameservers noted
- [ ] Nameservers updated at registrar
- [ ] A record created
- [ ] CNAME records created
- [ ] CAA records added
- [ ] Health checks configured (optional)
- [ ] Query logging enabled (optional)
- [ ] DNSSEC enabled (optional)
- [ ] Verified with CLI/dig

---

For more help, see [../TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
