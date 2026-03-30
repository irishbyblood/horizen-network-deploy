---
name: infrastructure
description: Guidelines for Docker, Docker Compose, Nginx, and deployment infrastructure files
applyTo: "docker-compose*.yml,Dockerfile*,*.sh,nginx/**/*"
---

# Infrastructure and Deployment Guidelines

## Docker Compose Best Practices

### Service Definitions
- Always specify explicit image versions (never use `latest` tag in production)
- Use Alpine-based images when available for smaller footprint
- Define restart policies: `restart: unless-stopped` for production services
- Include health checks for all critical services with appropriate intervals

### Example Health Check
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Network Configuration
- Use custom bridge networks for service isolation
- Never expose internal services directly via ports unless necessary
- Use service names for inter-service communication (Docker DNS)

### Volume Management
- Use named volumes for persistent data
- Mount read-only volumes where appropriate with `:ro` flag
- Always persist logs, data, and configuration to volumes
- Document volume purposes in comments

### Environment Variables
- Reference from .env file using `${VAR_NAME:-default_value}` syntax
- Never hardcode sensitive values
- Always provide sensible defaults where appropriate
- Group related variables together

## Shell Script Standards

### Script Headers
Every script must start with:
```bash
#!/bin/bash
set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
```

### Error Handling
- Check for required dependencies at script start
- Validate input parameters
- Provide helpful error messages
- Use `trap` for cleanup on exit

### Example Error Handling
```bash
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi
```

### Logging
- Log important actions to stdout
- Use consistent log format: `[TIMESTAMP] ACTION: message`
- Log errors to stderr
- Include script name in log messages

### Example Logging
```bash
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}
```

## Nginx Configuration

### Security Headers
Always include these security headers:
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
```

### SSL/TLS Configuration
- Use TLS 1.2 and 1.3 only
- Configure strong cipher suites
- Enable HSTS (HTTP Strict Transport Security)
- Always redirect HTTP to HTTPS in production

### Example SSL Block
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
add_header Strict-Transport-Security "max-age=31536000" always;
```

### Proxy Configuration
- Set appropriate timeouts for proxied services
- Forward real client IP addresses
- Configure buffer sizes for large requests
- Enable gzip compression

### Example Proxy Block
```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
```

## Dockerfile Best Practices

### Multi-Stage Builds
- Use multi-stage builds to minimize final image size
- Separate build and runtime stages
- Copy only necessary artifacts to final stage

### Layer Optimization
- Order instructions from least to most frequently changing
- Combine RUN commands where logical to reduce layers
- Clean up package manager cache in the same RUN command

### Example
```dockerfile
RUN apt-get update && \
    apt-get install -y package1 package2 && \
    rm -rf /var/lib/apt/lists/*
```

### Security
- Run as non-root user when possible
- Use specific base image versions (not `latest`)
- Scan images for vulnerabilities
- Keep base images updated

## Testing Infrastructure Changes

### Pre-Deployment Checks
1. Validate Docker Compose syntax:
   ```bash
   docker-compose config
   ```

2. Validate Nginx configuration:
   ```bash
   docker exec horizen-nginx nginx -t
   ```

3. Test in development first:
   ```bash
   ./scripts/deploy.sh dev
   ./scripts/health-check.sh
   ```

4. Check all services are running:
   ```bash
   docker-compose ps
   ```

5. Verify logs for errors:
   ```bash
   docker-compose logs --tail=50
   ```

### Shell Script Testing
- Use `shellcheck` to validate scripts:
  ```bash
  shellcheck scripts/*.sh
  ```
- Test with various input conditions
- Verify cleanup on error conditions
- Test both success and failure paths

## Deployment Workflow

### Development
1. Make changes to configuration files
2. Validate syntax with appropriate tools
3. Deploy to development environment
4. Run health checks
5. Verify service functionality
6. Check logs for warnings or errors

### Production
1. Test thoroughly in development
2. Review all configuration changes
3. Backup current production state
4. Deploy during maintenance window
5. Run comprehensive health checks
6. Monitor logs closely post-deployment
7. Have rollback plan ready

## Common Patterns

### Adding a New Service
1. Define service in docker-compose.yml
2. Add environment variables to .env.example
3. Configure health check
4. Add network connectivity
5. Update Nginx routing if web-accessible
6. Add to health-check.sh
7. Document in README.md

### Updating Service Version
1. Update image version in docker-compose.yml
2. Review changelog for breaking changes
3. Update configuration if needed
4. Test in development environment
5. Plan production upgrade
6. Monitor after upgrade

### SSL Certificate Renewal
1. Ensure ssl-setup.sh script is configured
2. Run renewal before expiration
3. Verify new certificates are loaded
4. Test HTTPS connections
5. Check certificate expiration date

## Environment-Specific Configuration

### Development (docker-compose.dev.yml)
- Expose additional ports for debugging
- Enable verbose logging
- Disable SSL/TLS requirements
- Use simplified configurations
- Mount source code for live reload

### Production (docker-compose.prod.yml)
- Enforce SSL/TLS
- Optimize performance settings
- Enable security features
- Use production-grade passwords
- Configure automated backups
- Set resource limits

## Troubleshooting Guidelines

### Service Won't Start
1. Check Docker logs: `docker-compose logs [service]`
2. Verify environment variables are set
3. Check port conflicts: `netstat -tulpn`
4. Verify volume permissions
5. Check dependency services are running

### Network Issues
1. Verify Docker network exists: `docker network ls`
2. Check service name resolution
3. Verify firewall rules
4. Test connectivity from container: `docker exec [container] ping [service]`
5. Review network configuration in docker-compose.yml

### Performance Issues
1. Check resource usage: `docker stats`
2. Review service logs for errors
3. Verify volume mount performance
4. Check for memory leaks
5. Review container resource limits

## Version Control

### Files to Commit
- Docker Compose configuration files
- Nginx configuration files
- Deployment scripts
- Documentation files
- .env.example (template only)

### Files to Ignore
- .env (contains secrets)
- SSL certificates and private keys
- Log files
- Volume data directories
- Temporary files
- Build artifacts

## Documentation Requirements

When making infrastructure changes:
1. Update relevant README files
2. Document new environment variables
3. Update architecture diagrams if needed
4. Add troubleshooting notes for common issues
5. Update deployment guides
6. Document breaking changes
