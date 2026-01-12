# Deployment Checklist for Multi-App Architecture

## Pre-Deployment Checklist

### 1. Environment Configuration

- [ ] Copy `.env.example` to `.env`
- [ ] Generate and set `JWT_SECRET_KEY`
  ```bash
  openssl rand -hex 32
  ```
- [ ] Set strong passwords for:
  - [ ] `POSTGRES_PASSWORD`
  - [ ] `MONGO_PASSWORD`
  - [ ] `REDIS_PASSWORD`
- [ ] Configure Stripe keys (if using payments):
  - [ ] `STRIPE_API_KEY`
  - [ ] `STRIPE_WEBHOOK_SECRET`
  - [ ] `STRIPE_PUBLISHABLE_KEY`
- [ ] Configure domain names:
  - [ ] `DOMAIN`
  - [ ] `API_DOMAIN`
  - [ ] `GENIESS_DOMAIN`
  - [ ] `ENTITY_DOMAIN`
  - [ ] `DRUID_DOMAIN`

### 2. DNS Configuration

- [ ] Add A record for main domain pointing to server IP
- [ ] Add CNAME records:
  - [ ] `api` → main domain
  - [ ] `geniess` → main domain
  - [ ] `entity` → main domain
  - [ ] `druid` → main domain
- [ ] Verify DNS propagation:
  ```bash
  ./dns/scripts/verify-dns.sh
  ```

### 3. SSL Certificates (Production)

- [ ] Run SSL setup script:
  ```bash
  sudo ./scripts/ssl-setup.sh
  ```
- [ ] Verify certificates are generated
- [ ] Update nginx configuration to enable SSL

### 4. System Requirements

- [ ] Docker installed (version 24.0+)
- [ ] Docker Compose installed (version 2.0+)
- [ ] Sufficient resources:
  - [ ] Minimum: 4 CPU, 8GB RAM, 100GB storage
  - [ ] Recommended: 8 CPU, 16GB RAM, 500GB storage

## Deployment Steps

### 1. Build Services

```bash
# Pull latest code
git pull origin main

# Build all services
docker compose build
```

### 2. Start Infrastructure

```bash
# Start all services
docker compose up -d

# Check service status
docker compose ps
```

### 3. Verify Services

```bash
# Check health of all services
curl http://localhost/health                    # Nginx
curl http://localhost:8000/health              # Auth-Billing
curl http://localhost:8001/health              # Geniess
curl http://localhost:8002/health              # Entity

# Or use the health check script
./scripts/health-check.sh
```

### 4. Test Authentication Flow

```bash
# Run the authentication test script
./scripts/test-auth.sh
```

### 5. Configure First Admin User

```bash
# Register admin user
curl -X POST http://api.${DOMAIN}/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@'${DOMAIN}'","password":"SecureAdminPass123!","full_name":"Admin User"}'

# Grant all entitlements to admin
TOKEN="<token_from_registration>"
curl -X POST "http://api.${DOMAIN}/api/entitlements/grant?email=admin@${DOMAIN}&entitlement=BUNDLE_DRUID_GENIESS" \
  -H "Authorization: Bearer $TOKEN"
curl -X POST "http://api.${DOMAIN}/api/entitlements/grant?email=admin@${DOMAIN}&entitlement=ENTITY" \
  -H "Authorization: Bearer $TOKEN"
```

## Post-Deployment Checklist

### 1. Service Access Verification

- [ ] Main website accessible at `http://${DOMAIN}`
- [ ] Geniess accessible at `http://geniess.${DOMAIN}` or `http://${DOMAIN}/geniess/`
- [ ] Entity accessible at `http://entity.${DOMAIN}` or `http://${DOMAIN}/entity/`
- [ ] Druid accessible at `http://druid.${DOMAIN}` or `http://${DOMAIN}/druid/`
- [ ] API accessible at `http://api.${DOMAIN}` or `http://${DOMAIN}/api/`

### 2. Authentication Testing

- [ ] User registration works
- [ ] User login works
- [ ] JWT tokens are generated correctly
- [ ] Token expiration works as expected

### 3. Entitlement Testing

- [ ] Access to Geniess denied without `BUNDLE_DRUID_GENIESS` entitlement
- [ ] Access to Geniess granted with `BUNDLE_DRUID_GENIESS` entitlement
- [ ] Access to Entity denied without `ENTITY` entitlement
- [ ] Access to Entity granted with `ENTITY` entitlement

### 4. Nginx Routing

- [ ] Subdomain routing works (geniess.domain, entity.domain, etc.)
- [ ] Path-based routing works (/geniess/, /entity/, etc.)
- [ ] CORS headers are set correctly
- [ ] Rate limiting is functional

### 5. Monitoring & Logs

- [ ] Check logs for errors:
  ```bash
  docker compose logs auth-billing
  docker compose logs geniess
  docker compose logs entity
  docker compose logs nginx
  ```
- [ ] Set up log rotation
- [ ] Configure monitoring/alerting

### 6. Backup Configuration

- [ ] Test backup script:
  ```bash
  ./scripts/backup.sh
  ```
- [ ] Configure automated backups (cron)
- [ ] Test restore procedure

### 7. Security Hardening

- [ ] SSL/TLS enabled and working
- [ ] Firewall configured (only ports 80, 443 open)
- [ ] Security headers verified
- [ ] Rate limiting tested
- [ ] Password policies enforced
- [ ] Webhook signatures validated (Stripe)

## Stripe Integration (Optional)

### 1. Stripe Setup

- [ ] Create Stripe account
- [ ] Create products:
  - [ ] "Druid + Geniess Bundle" - $5/month
  - [ ] "Entity Service" - $10/month
- [ ] Configure webhook endpoint:
  - URL: `https://api.${DOMAIN}/api/billing/webhook`
  - Events: `checkout.session.completed`, `customer.subscription.deleted`
- [ ] Get webhook signing secret

### 2. Environment Variables

- [ ] Add Stripe keys to `.env`
- [ ] Restart auth-billing service:
  ```bash
  docker compose restart auth-billing
  ```

### 3. Test Stripe Integration

- [ ] Test checkout flow
- [ ] Verify webhook receives events
- [ ] Verify entitlements are granted after payment
- [ ] Test subscription cancellation

## Rollback Plan

If deployment fails:

```bash
# Stop all services
docker compose down

# Restore from backup
# (restore database backups)

# Revert to previous version
git checkout <previous_commit>

# Restart services
docker compose up -d
```

## Maintenance

### Regular Tasks

- [ ] Monitor service health daily
- [ ] Review logs weekly
- [ ] Update dependencies monthly
- [ ] Rotate secrets quarterly
- [ ] Test backups quarterly

### Updates

```bash
# Pull latest changes
git pull origin main

# Rebuild services
docker compose build

# Restart with new version
docker compose up -d

# Verify services
./scripts/health-check.sh
```

## Troubleshooting

### Services Won't Start

1. Check logs: `docker compose logs <service_name>`
2. Verify environment variables
3. Check disk space: `df -h`
4. Check port conflicts: `netstat -tulpn | grep <port>`

### Authentication Issues

1. Verify JWT_SECRET_KEY is set
2. Check token expiration settings
3. Verify auth-billing service is reachable
4. Check for clock skew between containers

### Entitlement Issues

1. Check user's entitlements: `GET /api/auth/me`
2. Verify entitlement grant was successful
3. Check auth-billing service logs
4. Verify service can reach auth-billing

## Support

For issues or questions:
- Email: admin@horizen-network.com
- Documentation: `/docs/AUTHENTICATION.md`
- GitHub Issues: https://github.com/irishbyblood/horizen-network-deploy/issues
