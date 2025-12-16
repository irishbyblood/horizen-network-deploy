# Horizen Network - Production Quickstart Guide

This guide will help you deploy Horizen Network to production in minutes.

## 🚀 Quick Deployment (5 Steps)

### 1. Clone and Configure

```bash
# Clone repository
git clone https://github.com/irishbyblood/horizen-network-deploy.git
cd horizen-network-deploy

# Copy and configure environment
cp .env.example .env
nano .env
```

### 2. Set Required Environment Variables

Edit `.env` and configure:

```bash
# Domain Configuration
DOMAIN=horizen-network.com
ADMIN_EMAIL=admin@horizen-network.com

# Database Passwords (CHANGE THESE!)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
MONGO_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)

# Stripe Configuration (Get from https://dashboard.stripe.com)
STRIPE_SECRET_KEY=sk_live_xxxxx
STRIPE_PUBLIC_KEY=pk_live_xxxxx
STRIPE_WEBHOOK_SECRET=whsec_xxxxx
STRIPE_DRUID_GENIESS_PRICE_ID=price_xxxxx
STRIPE_ENTITY_PRICE_ID=price_xxxxx
```

### 3. Validate Prerequisites

```bash
./scripts/validate.sh
```

This checks:
- ✅ Docker and Docker Compose installed
- ✅ Required files present
- ✅ Environment variables set
- ✅ System resources adequate
- ✅ Ports available

### 4. Deploy to Production

```bash
./scripts/production-deploy.sh
```

This automatically:
1. Validates configuration
2. Creates backup of current state
3. Pulls latest code and images
4. Runs database migrations
5. Deploys all services
6. Performs health checks
7. Rolls back on failure

### 5. Verify Deployment

```bash
./scripts/health-check.sh
```

Access your services:
- **Main Site**: https://horizen-network.com
- **Subscription Dashboard**: https://horizen-network.com/subscription/
- **Druid Analytics**: https://druid.horizen-network.com
- **Geniess Platform**: https://geniess.horizen-network.com
- **Entity AI**: https://entity.horizen-network.com

## 📋 Pre-Deployment Checklist

### DNS Configuration

Configure these DNS records for `horizen-network.com`:

```
Type    Name      Value              TTL
A       @         YOUR_SERVER_IP     3600
A       druid     YOUR_SERVER_IP     3600
A       geniess   YOUR_SERVER_IP     3600
A       entity    YOUR_SERVER_IP     3600
CNAME   www       horizen-network.com  3600
```

Verify DNS propagation:
```bash
dig horizen-network.com +short
dig druid.horizen-network.com +short
```

### Stripe Setup

1. Create products in Stripe Dashboard:
   - **Druid + Geniess Bundle**: $15/month recurring
   - **Entity AI**: $5/month recurring

2. Copy price IDs to `.env`:
   ```bash
   STRIPE_DRUID_GENIESS_PRICE_ID=price_xxxxx
   STRIPE_ENTITY_PRICE_ID=price_xxxxx
   ```

3. Configure webhook endpoint:
   - URL: `https://horizen-network.com/api/payment/webhook`
   - Events: All subscription and payment events
   - Copy signing secret to `STRIPE_WEBHOOK_SECRET`

### SSL Certificates

SSL is automatically configured during deployment using Let's Encrypt.

To manually setup/renew:
```bash
sudo ./scripts/ssl-setup.sh
```

Certificates auto-renew via cron job.

### Firewall Rules

```bash
# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH

# Enable firewall
sudo ufw enable
```

## 🔧 Management Commands

### View Status
```bash
docker-compose ps
./scripts/health-check.sh
docker stats
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f payment-webhooks
```

### Backup
```bash
# Create backup
./scripts/backup.sh

# List backups
./scripts/restore.sh --list

# Restore from backup
./scripts/restore.sh --date 20241215_120000
```

### Rollback
```bash
# Rollback to previous backup
./scripts/rollback.sh --backup 20241215_120000

# Rollback code to commit
./scripts/rollback.sh --commit abc123

# Rollback to tag
./scripts/rollback.sh --tag v1.0.0
```

### Database Migrations
```bash
# Run migrations
./migrations/run-migrations.sh

# Check migration status
docker-compose exec postgres psql -U druid -d horizen_network -c "SELECT * FROM schema_migrations;"
```

### Update Deployment
```bash
# Pull latest changes and deploy
git pull origin main
./scripts/production-deploy.sh
```

## 🔒 Security Best Practices

### 1. Change Default Passwords
```bash
# Generate secure passwords
POSTGRES_PASSWORD=$(openssl rand -base64 32)
MONGO_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)
```

### 2. Enable Automatic Security Updates
```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Configure Fail2ban
```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Regular Backups
```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * cd /opt/horizen-network-deploy && ./scripts/backup.sh >> /var/log/horizen-backup.log 2>&1
```

### 5. Monitor Logs
```bash
# Setup log rotation
sudo nano /etc/logrotate.d/horizen-network

# Add:
/var/log/horizen-*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
```

## 📊 Monitoring Setup

### Prometheus Metrics
Access Prometheus at: `http://localhost:9090` (not exposed publicly)

### Grafana Dashboards
```bash
# Deploy Grafana (optional)
docker-compose -f docker-compose.monitoring.yml up -d

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### Health Monitoring
```bash
# Automated health checks every 5 minutes
crontab -e

# Add:
*/5 * * * * cd /opt/horizen-network-deploy && ./scripts/health-check.sh >> /var/log/horizen-health.log 2>&1
```

## 🧪 Testing

### Test Payment Integration
1. Visit: https://horizen-network.com/subscription/pricing.html
2. Click "Get Started" on a plan
3. Use Stripe test card: `4242 4242 4242 4242`
4. Complete checkout
5. Verify subscription in dashboard

### Test Services
```bash
# Test Nginx
curl -I https://horizen-network.com

# Test Druid
curl https://druid.horizen-network.com/status

# Test payment webhook
curl -X POST https://horizen-network.com/api/payment/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

## 🚨 Troubleshooting

### Services Won't Start
```bash
# Check logs
docker-compose logs

# Check system resources
free -h
df -h
docker system df

# Restart services
docker-compose down
docker-compose up -d
```

### Payment Webhook Failures
```bash
# Check webhook logs
docker-compose logs payment-webhooks

# Verify webhook secret
grep STRIPE_WEBHOOK_SECRET .env

# Test webhook locally
stripe listen --forward-to localhost:5000/webhook
```

### SSL Certificate Issues
```bash
# Check certificate
sudo certbot certificates

# Renew certificate
sudo certbot renew

# Restart nginx
docker-compose restart nginx
```

### Database Connection Errors
```bash
# Check database status
docker-compose exec postgres pg_isready

# Check connections
docker-compose exec postgres psql -U druid -c "SELECT count(*) FROM pg_stat_activity;"

# Restart database
docker-compose restart postgres
```

## 📞 Support

### Documentation
- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Application Setup](docs/APPLICATION_SETUP.md)
- [DNS Configuration](docs/DNS_CONFIGURATION.md)
- [Payment Setup](payment/README.md)

### Getting Help
- Check documentation in `docs/` directory
- Review logs: `docker-compose logs`
- Create GitHub issue with:
  - Error messages
  - System information
  - Steps to reproduce

## 🔄 Regular Maintenance

### Daily
- [ ] Monitor service health
- [ ] Check backup completion
- [ ] Review error logs

### Weekly
- [ ] Review payment transactions
- [ ] Check disk space usage
- [ ] Update Docker images

### Monthly
- [ ] Rotate passwords (optional)
- [ ] Review and update SSL certificates
- [ ] System security updates
- [ ] Review and optimize database

## 📈 Scaling

### Vertical Scaling
```bash
# Update resource limits in docker-compose.prod.yml
# Increase memory/CPU for Druid services
resources:
  limits:
    cpus: '4'
    memory: 8G
```

### Horizontal Scaling
```bash
# Deploy to Kubernetes
kubectl apply -f kubernetes/production/

# Scale deployments
kubectl scale deployment druid-historical --replicas=3
```

## 🎉 Success!

Your Horizen Network is now running in production!

- ✅ Services deployed and healthy
- ✅ SSL certificates configured
- ✅ Payment integration active
- ✅ Monitoring enabled
- ✅ Backups scheduled

**Next Steps:**
1. Test all functionality
2. Configure monitoring alerts
3. Set up backup notifications
4. Document custom configurations
5. Train team on operations

---

**Need Help?** Check the [documentation](docs/) or create an issue on GitHub.
