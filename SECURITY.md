# Security Policy

## Overview

Security is a top priority for the Horizen Network deployment infrastructure. This document outlines our security practices, vulnerability reporting procedures, and best practices for maintaining a secure deployment.

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please follow these steps:

### 1. Do Not Public Disclose

Please **do not** create a public GitHub issue for security vulnerabilities. Public disclosure could put all users at risk.

### 2. Report Privately

Send an email to: **security@horizen-network.com** (or create a private security advisory on GitHub)

Include the following information:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### 3. Response Timeline

- **24 hours**: Initial response acknowledging receipt
- **72 hours**: Assessment of severity and impact
- **7 days**: Plan for mitigation and fix
- **30 days**: Release of security patch (if applicable)

### 4. Disclosure Policy

We follow responsible disclosure:
- Security issues will be fixed before public disclosure
- Credit will be given to researchers who report vulnerabilities
- CVE numbers will be assigned for significant vulnerabilities

## Security Best Practices

### 1. Secrets Management

#### Never Commit Secrets
- ✅ Use `.env` files (excluded by `.gitignore`)
- ✅ Use environment variables
- ✅ Use secret management services (AWS Secrets Manager, HashiCorp Vault)
- ❌ Never commit `.env` files with real credentials
- ❌ Never hardcode passwords in configuration files

#### Generate Strong Passwords
```bash
# Generate a strong random password
openssl rand -base64 32

# Or use pwgen
pwgen -s 32 1
```

#### Rotate Credentials Regularly
- Database passwords: Every 90 days
- API keys: Every 180 days
- SSL certificates: Automatic renewal via Let's Encrypt

### 2. Network Security

#### Firewall Configuration
```bash
# Allow only necessary ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

#### Rate Limiting
- Nginx rate limiting is configured in `nginx/nginx.conf`
- API rate limits: 30 requests/second
- General rate limits: 10 requests/second

#### DDoS Protection
Consider using:
- Cloudflare (CDN with DDoS protection)
- AWS Shield
- Fail2ban for SSH protection

### 3. SSL/TLS Configuration

#### Use Strong Protocols
- ✅ TLS 1.2 and TLS 1.3
- ❌ SSL v2, SSL v3, TLS 1.0, TLS 1.1

#### Certificate Management
```bash
# Obtain certificates
sudo ./scripts/ssl-setup.sh

# Verify certificate
openssl s_client -connect horizen-network.com:443 -servername horizen-network.com

# Check expiration
openssl s_client -connect horizen-network.com:443 -servername horizen-network.com 2>/dev/null | openssl x509 -noout -dates
```

#### HSTS Headers
Strict-Transport-Security headers are configured in `nginx/conf.d/ssl.conf`

### 4. Docker Security

#### Use Official Images
- ✅ Use official images from Docker Hub
- ✅ Pin specific versions (e.g., `nginx:alpine`, not `nginx:latest`)
- ❌ Avoid unknown third-party images

#### Scan for Vulnerabilities
```bash
# Scan images with Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image nginx:alpine

# Scan with Docker Scout
docker scout cves nginx:alpine
```

#### Minimize Image Size
- Use Alpine-based images when possible
- Multi-stage builds for custom images
- Remove unnecessary packages

#### Run as Non-Root
When creating custom Dockerfiles:
```dockerfile
FROM nginx:alpine
RUN addgroup -g 1000 appuser && adduser -D -u 1000 -G appuser appuser
USER appuser
```

### 5. Database Security

#### PostgreSQL
```bash
# Strong password
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Restrict connections
# Edit postgresql.conf:
# listen_addresses = 'localhost'

# Use SSL for connections
# ssl = on
# ssl_cert_file = '/path/to/cert.pem'
# ssl_key_file = '/path/to/key.pem'
```

#### MongoDB
```bash
# Enable authentication
MONGO_PASSWORD=$(openssl rand -base64 32)

# Use roles
# Create user with specific permissions:
db.createUser({
  user: "horizen",
  pwd: "STRONG_PASSWORD",
  roles: [{ role: "readWrite", db: "horizen_network" }]
})
```

#### Redis
```bash
# Require password
REDIS_PASSWORD=$(openssl rand -base64 32)

# Rename dangerous commands
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG "CONFIG_HIDDEN"
```

### 6. Access Control

#### SSH Hardening
```bash
# Edit /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2

# Restart SSH
sudo systemctl restart sshd
```

#### Sudo Access
```bash
# Limit sudo access
# Edit /etc/sudoers
user ALL=(ALL) NOPASSWD: /usr/bin/docker-compose

# Enable sudo logging
Defaults logfile=/var/log/sudo.log
```

#### File Permissions
```bash
# Secure sensitive files
chmod 600 .env
chmod 600 ssl/*.key
chmod 700 scripts/

# Verify permissions
find . -type f -name "*.key" -exec chmod 600 {} \;
find . -type f -name "*.pem" -exec chmod 600 {} \;
```

### 7. Monitoring and Logging

#### Enable Audit Logging
```bash
# Install auditd
sudo apt-get install auditd

# Monitor important files
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -w /opt/horizen-network-deploy/.env -p wa -k env_changes
```

#### Log Management
- Centralize logs (ELK stack, Splunk, CloudWatch)
- Rotate logs regularly
- Monitor for suspicious activity
- Set up alerts for security events

#### Security Monitoring
```bash
# Monitor failed login attempts
sudo grep "Failed password" /var/log/auth.log

# Monitor sudo usage
sudo grep "sudo" /var/log/auth.log

# Check for rootkits
sudo apt-get install rkhunter
sudo rkhunter --check
```

### 8. Backup Security

#### Encrypt Backups
```bash
# Encrypt backup with GPG
gpg --symmetric --cipher-algo AES256 backup.tar.gz

# Decrypt backup
gpg --decrypt backup.tar.gz.gpg > backup.tar.gz
```

#### Secure Backup Storage
- Store backups in encrypted storage (S3 with encryption, Azure Blob with encryption)
- Use separate credentials for backup access
- Test backup restoration regularly
- Store backups in multiple geographic locations

### 9. Application Security

#### Druid Security
```properties
# Enable authentication
druid.auth.authenticatorChain=["basic"]
druid.auth.authenticator.basic.type=basic
druid.auth.authenticator.basic.initialAdminPassword=CHANGE_ME

# Enable authorization
druid.auth.authorizers=["basic"]
druid.auth.authorizer.basic.type=basic
```

#### Nginx Security Headers
Already configured in `nginx/nginx.conf`:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy

### 10. Incident Response

#### In Case of Security Breach

1. **Isolate**: Disconnect affected systems
2. **Assess**: Determine scope and impact
3. **Contain**: Stop the breach from spreading
4. **Eradicate**: Remove the threat
5. **Recover**: Restore services
6. **Review**: Post-incident analysis

#### Emergency Contacts
- Security Team: security@horizen-network.com
- On-Call: oncall@horizen-network.com

## Compliance

### Data Protection
- Follow GDPR guidelines for EU users
- Implement data retention policies
- Provide data export/deletion mechanisms

### Audit Trail
- Maintain logs for at least 90 days
- Regular security audits
- Penetration testing annually

## Security Checklist

Before going to production:

- [ ] Change all default passwords
- [ ] Enable SSL/TLS with valid certificates
- [ ] Configure firewall rules
- [ ] Enable fail2ban for SSH protection
- [ ] Setup automated backups
- [ ] Configure monitoring and alerting
- [ ] Review and harden SSH configuration
- [ ] Scan Docker images for vulnerabilities
- [ ] Enable database authentication
- [ ] Configure rate limiting
- [ ] Setup security headers
- [ ] Enable audit logging
- [ ] Test backup restoration
- [ ] Document security procedures
- [ ] Train team on security practices

## Updates and Patches

### Regular Updates
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d

# Update Docker itself
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

### Security Bulletins
Subscribe to:
- Docker security advisories
- Ubuntu security notices
- Apache Druid security mailing list
- Nginx security advisories

## Additional Resources

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Nginx Security Controls](https://nginx.org/en/docs/http/ngx_http_ssl_module.html)
- [Apache Druid Security](https://druid.apache.org/docs/latest/operations/security-overview.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

## Contact

For security concerns:
- Email: security@horizen-network.com
- GitHub Security Advisories: Use GitHub's private reporting feature

---

**Last Updated**: December 2024

**Note**: This is a living document. Security practices should be reviewed and updated regularly.
