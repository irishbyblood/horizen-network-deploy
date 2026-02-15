---
name: security
description: Security guidelines and requirements for all code and configuration changes
applyTo: "**/*"
excludeAgent: none
---

# Security Guidelines

## Core Security Principles

### Defense in Depth
- Implement multiple layers of security controls
- Never rely on a single security mechanism
- Assume breach: design with the assumption that defenses may be bypassed

### Least Privilege
- Services should run with minimum required permissions
- Avoid running containers as root user
- Restrict network access to only required services
- Limit file system access with read-only mounts where possible

### Secure by Default
- Default configurations must be secure
- Security features should be enabled by default
- Require explicit action to reduce security

## Secrets Management

### Never Commit Secrets
**Prohibited in repository:**
- Passwords or passphrases
- API keys or tokens
- Private keys or certificates
- OAuth client secrets
- Database connection strings with credentials
- Session keys or JWT secrets

### Proper Secret Handling
```bash
# Bad - hardcoded secret
API_KEY="sk-1234567890abcdef"

# Good - environment variable
API_KEY="${API_KEY}"

# Good - with validation
if [ -z "${API_KEY}" ]; then
    echo "ERROR: API_KEY environment variable must be set"
    exit 1
fi
```

### Environment Variables
- Store secrets only in `.env` files (never committed)
- Use `.env.example` as template with placeholder values
- Document all required environment variables
- Use strong default passwords in development, require changes in production

## Configuration Security

### SSL/TLS Requirements

**Production Requirements:**
- TLS 1.2 minimum (prefer TLS 1.3)
- Strong cipher suites only
- Valid certificates from trusted CA
- HSTS enabled with appropriate max-age
- Redirect all HTTP to HTTPS

**Development:**
- Can use self-signed certificates
- Document certificate generation process
- Never use development certificates in production

### Nginx Security Headers

**Required headers for all responses:**
```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self'" always;
```

**Additional for production:**
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

### Docker Security

**Container Security:**
```yaml
# Run as non-root user
user: "1000:1000"

# Read-only root filesystem
read_only: true

# Drop all capabilities, add only what's needed
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE

# No new privileges
security_opt:
  - no-new-privileges:true
```

**Image Security:**
- Use official images from trusted sources
- Pin specific image versions (not `latest`)
- Scan images for vulnerabilities regularly
- Keep base images updated with security patches

## Network Security

### Port Exposure
- Never expose internal services directly to internet
- Use Nginx reverse proxy for web services
- Bind development ports to localhost only
- Document why each exposed port is necessary

### Network Segmentation
```yaml
networks:
  # Frontend network - exposed services
  frontend:
    driver: bridge
  
  # Backend network - internal services only
  backend:
    driver: bridge
    internal: true
```

### Firewall Rules
- Block all incoming traffic by default
- Allow only necessary ports (80, 443 for web)
- Restrict SSH access by IP when possible
- Use fail2ban or similar for brute force protection

## Input Validation

### Environment Variables
Always validate environment variables before use:
```bash
# Validate format
if [[ ! "${EMAIL}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    echo "ERROR: Invalid email format"
    exit 1
fi

# Validate numeric range
if [ "${PORT}" -lt 1024 ] || [ "${PORT}" -gt 65535 ]; then
    echo "ERROR: Port must be between 1024 and 65535"
    exit 1
fi
```

### File Paths
- Validate file paths to prevent directory traversal
- Use absolute paths where possible
- Sanitize user input used in file operations

```bash
# Bad - vulnerable to path traversal
cat "/var/log/${USER_INPUT}"

# Good - validate input
SAFE_LOG=$(basename "${USER_INPUT}")
if [[ ! "${SAFE_LOG}" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "ERROR: Invalid log file name"
    exit 1
fi
cat "/var/log/${SAFE_LOG}"
```

## Authentication & Authorization

### Database Access
- Use unique credentials for each service
- Implement connection pooling with limits
- Use read-only users where write access not needed
- Regularly rotate database passwords

### Service-to-Service Authentication
- Use internal Docker networks for service communication
- Implement mutual TLS where appropriate
- Use service accounts with minimal permissions
- Log all authentication attempts

### External API Access
- Store API keys in environment variables
- Implement rate limiting
- Use API keys with minimal required scopes
- Rotate keys regularly
- Monitor for unusual access patterns

## Logging and Monitoring

### Security Logging
**Always log:**
- Authentication attempts (success and failure)
- Authorization failures
- Configuration changes
- Service start/stop events
- SSL certificate operations
- Database connection events

**Never log:**
- Passwords or API keys
- Session tokens
- Credit card numbers
- Personal identification information
- Full SQL queries (may contain sensitive data)

### Log Format
```bash
# Include timestamp, severity, source, and message
log_security() {
    echo "[$(date -Iseconds)] SECURITY: $*" >&2
}

# Usage
log_security "Failed login attempt from ${IP_ADDRESS}"
```

### Monitoring
- Monitor for unusual traffic patterns
- Alert on failed authentication attempts
- Track certificate expiration dates
- Monitor disk space for log directories
- Set up alerts for service failures

## Dependency Management

### Package Security
- Use official package repositories
- Pin package versions in requirements files
- Regularly update dependencies for security patches
- Review release notes for security fixes

### Vulnerability Scanning
- Scan Docker images for vulnerabilities
- Review dependency security advisories
- Update packages with known vulnerabilities promptly
- Document any accepted security risks

## Incident Response

### Security Issues
When a security issue is discovered:
1. Assess the severity and impact
2. Document the issue privately
3. Develop and test a fix
4. Deploy fix to production immediately if critical
5. Review logs for signs of exploitation
6. Document lessons learned

### Breach Response
If a breach is suspected:
1. Isolate affected systems
2. Preserve evidence (logs, snapshots)
3. Notify appropriate stakeholders
4. Assess scope of compromise
5. Implement remediation steps
6. Conduct post-incident review

## Security Testing

### Pre-Deployment Checks
- [ ] No secrets in code or configuration files
- [ ] SSL/TLS properly configured
- [ ] Security headers present
- [ ] Services run as non-root users
- [ ] Network ports properly restricted
- [ ] Input validation implemented
- [ ] Logging configured correctly
- [ ] Dependencies up to date

### Regular Security Reviews
Quarterly:
- Review access logs for anomalies
- Check for outdated dependencies
- Verify SSL certificate expiration dates
- Review firewall rules
- Audit user accounts and permissions

Annually:
- Conduct penetration testing
- Review and update security policies
- Audit third-party integrations
- Review disaster recovery procedures

## Compliance

### Data Protection
- Follow GDPR guidelines for EU users
- Implement data minimization
- Provide data export/deletion capabilities
- Maintain audit logs of data access

### Security Standards
- Follow OWASP Top 10 guidelines
- Implement CIS Docker Benchmarks
- Follow NIST Cybersecurity Framework
- Adhere to SOC 2 requirements if applicable

## Common Vulnerabilities

### Prevent These Issues

**SQL Injection:**
- Use parameterized queries
- Validate input before database operations
- Use ORM frameworks properly

**Cross-Site Scripting (XSS):**
- Sanitize all user input
- Use Content Security Policy headers
- Encode output properly

**Cross-Site Request Forgery (CSRF):**
- Implement CSRF tokens
- Use SameSite cookie attribute
- Verify origin headers

**Path Traversal:**
- Validate file paths
- Use allowlist of permitted paths
- Avoid user input in file operations

**Command Injection:**
- Never pass user input directly to shell commands
- Use parameter arrays instead of string concatenation
- Validate input against allowlist

## Security Automation

### Automated Checks
Implement automated security checks in CI/CD:
```bash
# Example security check script
#!/bin/bash
set -e

echo "Running security checks..."

# Check for secrets
if git diff --staged | grep -iE "(password|api_key|secret).*=.*['\"].*['\"]"; then
    echo "ERROR: Possible secret in staged files"
    exit 1
fi

# Validate SSL configuration
docker exec horizen-nginx nginx -t

# Check for running containers as root
if docker ps --format '{{.Names}}' | xargs -I {} sh -c 'docker exec {} id -u' | grep -q '^0$'; then
    echo "WARNING: Some containers running as root"
fi

echo "Security checks passed"
```

## Security Documentation

### Required Documentation
- Document all security-relevant configurations
- Maintain list of ports and their purposes
- Document authentication mechanisms
- Keep inventory of secrets and their locations
- Document incident response procedures

### Security Updates
When updating security-related code:
- Document the security issue being addressed
- Explain the fix in commit messages
- Update security documentation
- Add tests to prevent regression

## Reporting Security Issues

If you discover a security vulnerability:
1. Do NOT create a public issue
2. Email security contact (documented in SECURITY.md)
3. Include detailed description and reproduction steps
4. Wait for acknowledgment before public disclosure
5. Allow reasonable time for fix before disclosure

## Security Exceptions

### When Deviating from Guidelines
If you must deviate from these security guidelines:
1. Document the reason in code comments
2. Add TODO with remediation plan
3. Create issue to track technical debt
4. Get approval from security contact
5. Set timeline for compliance

### Example
```yaml
# SECURITY EXCEPTION: Running as root required for port 80 binding
# TODO: Implement capability-based solution (issue #123)
# Approved: 2024-01-15, Review by: 2024-07-15
user: root
```

## Resources

### Security Tools
- **OWASP ZAP**: Web application security scanner
- **Docker Bench**: Docker security audit tool
- **Trivy**: Container vulnerability scanner
- **Let's Encrypt**: Free SSL/TLS certificates

### Learning Resources
- OWASP Top 10: https://owasp.org/www-project-top-ten/
- CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker
- NIST Cybersecurity Framework: https://www.nist.gov/cyberframework
