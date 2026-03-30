# Horizen Network Deployment - Copilot Instructions

## Project Overview

This is a comprehensive deployment infrastructure for hosting advanced data analytics and intelligence platforms. The repository contains Docker-based infrastructure-as-code for deploying:
- Apache Druid for real-time analytics
- Nginx reverse proxy with SSL/TLS support
- Complete monitoring and logging stack
- Automated deployment and health check scripts

## Technology Stack

- **Containerization**: Docker 24.0+, Docker Compose 2.0+
- **Web Server**: Nginx Alpine
- **Data Analytics**: Apache Druid 26.0+
- **Databases**: PostgreSQL 15, ZooKeeper 3.8
- **Scripting**: Bash shell scripts
- **Configuration**: Environment variables via .env files

## Key Principles

### 1. Infrastructure as Code
- All infrastructure must be defined declaratively in Docker Compose files
- Separate configurations for development (`docker-compose.dev.yml`) and production (`docker-compose.prod.yml`)
- Never hardcode secrets or sensitive data - use environment variables

### 2. Security First
- All external communications must use HTTPS in production
- SSL certificates managed via Let's Encrypt or similar
- Security headers must be configured in Nginx
- Never commit secrets, API keys, or passwords to the repository
- Use `.env.example` for template configurations, never `.env` directly

### 3. Documentation
- Maintain clear README files in each directory
- Document all environment variables with descriptions
- Include architecture diagrams in major documentation updates
- Keep deployment guides up-to-date with configuration changes

### 4. Modularity
- Each service should be independently configurable
- Use volume mounts for persistent data
- Network isolation via Docker networks
- Health checks for all critical services

## Common Tasks

### Building and Deploying

```bash
# Development deployment
./scripts/deploy.sh dev

# Production deployment
./scripts/deploy.sh prod

# Health check
./scripts/health-check.sh

# SSL setup (production)
sudo ./scripts/ssl-setup.sh
```

### Testing and Validation

```bash
# Verify Docker Compose configuration
docker-compose config

# Check service logs
docker-compose logs -f [service-name]

# Test Nginx configuration
docker exec horizen-nginx nginx -t

# Verify DNS configuration
./dns/scripts/verify-dns.sh
```

### Maintenance

```bash
# Backup data
./scripts/backup.sh

# Update services
docker-compose pull
docker-compose up -d

# Clean up unused resources
docker system prune -a
```

## File Organization

- `/docker-compose.yml` - Base Docker Compose configuration
- `/docker-compose.dev.yml` - Development overrides
- `/docker-compose.prod.yml` - Production overrides
- `/scripts/` - Deployment and maintenance scripts
- `/nginx/` - Nginx configuration and SSL certificates
- `/dns/` - DNS configuration and verification scripts
- `/docs/` - Comprehensive documentation
- `/monitoring/` - Monitoring stack configuration
- `/public/` - Static website files

## Guidelines for Changes

### When Adding New Services
1. Add service definition to `docker-compose.yml`
2. Create environment-specific overrides in dev/prod files
3. Configure health checks
4. Add to Nginx routing if web-accessible
5. Update documentation in README.md
6. Add to health-check.sh script

### When Modifying Scripts
1. Maintain POSIX shell compatibility (avoid bashisms where possible)
2. Add error handling with set -e
3. Include usage help messages
4. Log important actions to stdout
5. Test in both development and production modes

### When Updating Configuration
1. Never modify production .env directly
2. Update .env.example with new variables
3. Document all new environment variables
4. Test changes in development first
5. Update relevant documentation files

## Prohibited Actions

- **Never** commit secrets, passwords, or API keys
- **Never** expose internal services directly to the internet
- **Never** modify running production containers directly (use docker-compose)
- **Never** remove health checks from services
- **Never** disable security headers in Nginx
- **Never** hardcode IP addresses or domain names (use environment variables)
- **Never** run services as root when it can be avoided
- **Never** bypass SSL certificate validation

## DNS Configuration

This project requires proper DNS configuration for production deployment:

### Required DNS Records
- **A Record**: Main domain pointing to server IP
- **CNAME Records**: www, druid, geniess, entity, api subdomains

### DNS Verification
Always verify DNS propagation before deploying to production:
```bash
./dns/scripts/verify-dns.sh
```

See [dns/README.md](../dns/README.md) for detailed DNS setup instructions.

## Monitoring and Logging

- All services should log to stdout/stderr for Docker logging
- Nginx access and error logs are persisted to volumes
- Use `docker-compose logs` for troubleshooting
- Health check scripts provide automated status monitoring

## Support and Troubleshooting

### Common Issues
1. **Service won't start**: Check logs with `docker-compose logs [service]`
2. **Connection refused**: Verify service is running and network configuration
3. **SSL errors**: Ensure certificates are valid and properly configured
4. **DNS not resolving**: Wait for propagation or check DNS records

### Getting Help
- Check existing documentation in `/docs/`
- Review service logs for error messages
- Verify environment variables are set correctly
- Test configuration changes in development first

## Code Quality Standards

- Shell scripts must pass shellcheck validation
- Docker Compose files must validate with `docker-compose config`
- Nginx configuration must pass `nginx -t` validation
- All scripts must have execute permissions set correctly
- Use consistent indentation (2 spaces for YAML, 4 for shell scripts)
