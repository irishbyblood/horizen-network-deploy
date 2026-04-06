# Production Security Checklist

Complete this checklist before deploying to production and review regularly.

## 🔐 Credentials and Secrets

- [ ] All default passwords changed
- [ ] Strong passwords generated (32+ characters)
- [ ] `.env` file never committed to Git
- [ ] Stripe API keys are production keys (not test keys)
- [ ] Database passwords are unique and secure
- [ ] Stripe webhook secret is configured
- [ ] All secrets stored securely (not in code)
- [ ] API keys rotated regularly (every 90 days)
- [ ] Old API keys revoked
- [ ] No hardcoded credentials in source code

## 🌐 Network Security

- [ ] Firewall configured (UFW or iptables)
- [ ] Only ports 22, 80, 443 exposed
- [ ] SSH key-based authentication enabled
- [ ] Password authentication disabled for SSH
- [ ] Root SSH login disabled
- [ ] Fail2ban installed and configured
- [ ] Rate limiting enabled on all APIs
- [ ] DDoS protection configured (Cloudflare/AWS Shield)
- [ ] VPN configured for admin access (optional)
- [ ] Internal services not exposed publicly

## 🔒 SSL/TLS Configuration

- [ ] SSL certificates obtained from Let's Encrypt
- [ ] All domains have valid certificates
- [ ] HTTP redirects to HTTPS
- [ ] HSTS header enabled
- [ ] TLS 1.2+ only (no SSL v3, TLS 1.0/1.1)
- [ ] Strong cipher suites configured
- [ ] Certificate auto-renewal configured
- [ ] Certificate expiry monitoring enabled
- [ ] OCSP stapling enabled
- [ ] SSL Labs grade A or A+

## 🐳 Docker Security

- [ ] Docker daemon secured
- [ ] Containers run as non-root users
- [ ] Official images used where possible
- [ ] Image versions pinned (no :latest)
- [ ] Images scanned for vulnerabilities
- [ ] Unnecessary packages removed from images
- [ ] Secrets not in Dockerfiles
- [ ] Resource limits set for containers
- [ ] Health checks configured
- [ ] Logging configured for all containers

## 💳 Payment Security

- [ ] PCI DSS compliance reviewed
- [ ] No card data stored locally
- [ ] All payment data handled by Stripe
- [ ] Webhook signatures verified
- [ ] HTTPS enforced for payment pages
- [ ] CSP headers configured
- [ ] Payment endpoints rate limited
- [ ] Stripe webhook endpoint secured
- [ ] Test mode disabled in production
- [ ] Payment logs secured and encrypted

## 🗄️ Database Security

### PostgreSQL
- [ ] Strong database passwords
- [ ] Connections limited to localhost/container network
- [ ] SSL enabled for connections
- [ ] Regular backups configured
- [ ] Backup encryption enabled
- [ ] Point-in-time recovery configured
- [ ] Query logging enabled
- [ ] Unused extensions disabled
- [ ] Permissions properly configured
- [ ] Database firewall rules set

### MongoDB
- [ ] Authentication enabled
- [ ] Authorization configured
- [ ] Network access restricted
- [ ] Encryption at rest enabled
- [ ] Audit logging enabled
- [ ] Regular backups configured
- [ ] Replica set configured (if needed)
- [ ] JavaScript execution disabled
- [ ] Server-side JavaScript restricted

### Redis
- [ ] Password authentication enabled
- [ ] Dangerous commands disabled/renamed
- [ ] Network access restricted
- [ ] Persistence configured
- [ ] Backup strategy in place
- [ ] Memory limits set
- [ ] Key expiration configured

## 📊 Logging and Monitoring

- [ ] Centralized logging configured
- [ ] Log rotation enabled
- [ ] Failed login attempts logged
- [ ] Database query logging enabled
- [ ] Application error logging configured
- [ ] Audit logs for sensitive operations
- [ ] Log retention policy defined
- [ ] Monitoring alerts configured
- [ ] Prometheus metrics exposed
- [ ] Grafana dashboards created
- [ ] Alert notifications setup (Slack/Email)
- [ ] Uptime monitoring configured
- [ ] Performance monitoring enabled

## 🔄 Backup and Recovery

- [ ] Automated daily backups configured
- [ ] Backup verification scheduled
- [ ] Backups stored off-site
- [ ] Backup encryption enabled
- [ ] Restore procedure documented
- [ ] Restore tested successfully
- [ ] Backup retention policy defined
- [ ] Point-in-time recovery possible
- [ ] Disaster recovery plan documented
- [ ] RTO/RPO defined and achievable

## 🚀 Deployment Security

- [ ] CI/CD pipeline secured
- [ ] Code review required for merges
- [ ] Automated security scanning enabled
- [ ] Dependency vulnerability scanning
- [ ] Container image scanning
- [ ] SAST (Static Analysis) configured
- [ ] Secrets scanning enabled
- [ ] Rollback procedure documented
- [ ] Blue-green deployment configured
- [ ] Canary deployment available

## 👥 Access Control

- [ ] Principle of least privilege applied
- [ ] Role-based access control (RBAC)
- [ ] Multi-factor authentication enabled
- [ ] SSH keys managed properly
- [ ] Regular access reviews conducted
- [ ] Offboarding process defined
- [ ] Service accounts properly secured
- [ ] Admin accounts limited
- [ ] Session timeouts configured
- [ ] Failed login lockouts enabled

## 📱 Application Security

- [ ] Input validation implemented
- [ ] SQL injection prevention
- [ ] XSS protection enabled
- [ ] CSRF protection enabled
- [ ] Security headers configured
- [ ] Content Security Policy set
- [ ] CORS properly configured
- [ ] API authentication required
- [ ] API authorization implemented
- [ ] Rate limiting on all endpoints
- [ ] File upload restrictions
- [ ] Error messages don't leak info
- [ ] Session management secure
- [ ] Cookie security flags set

## 📋 Compliance and Documentation

- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] GDPR compliance reviewed (if applicable)
- [ ] Data retention policy defined
- [ ] Security incident response plan
- [ ] Security contacts documented
- [ ] Vulnerability disclosure policy
- [ ] Security documentation up to date
- [ ] Compliance audit conducted
- [ ] Penetration testing completed

## 🔧 System Hardening

- [ ] Unnecessary services disabled
- [ ] System packages up to date
- [ ] Automatic security updates enabled
- [ ] Kernel hardening applied
- [ ] File system permissions reviewed
- [ ] SELinux/AppArmor enabled (optional)
- [ ] Intrusion detection system (IDS)
- [ ] File integrity monitoring (AIDE/Tripwire)
- [ ] System audit logging (auditd)
- [ ] Time synchronization (NTP) configured

## 🧪 Testing

- [ ] Security tests in CI/CD pipeline
- [ ] Penetration testing conducted
- [ ] Vulnerability scanning automated
- [ ] Load testing completed
- [ ] Backup restore tested
- [ ] Disaster recovery drill conducted
- [ ] SSL configuration tested
- [ ] Payment flow tested
- [ ] Authentication tested
- [ ] Authorization tested

## 📞 Incident Response

- [ ] Security incident response plan
- [ ] Security contacts list maintained
- [ ] Incident escalation procedure
- [ ] Communication plan defined
- [ ] Post-incident review process
- [ ] Security incident log maintained
- [ ] Breach notification procedure
- [ ] Evidence preservation procedure
- [ ] Forensics tools available
- [ ] Legal contacts identified

## 🔄 Regular Maintenance

### Daily
- [ ] Review security logs
- [ ] Check backup completion
- [ ] Monitor for anomalies
- [ ] Review failed login attempts

### Weekly
- [ ] Review access logs
- [ ] Check for security updates
- [ ] Review monitoring alerts
- [ ] Scan for vulnerabilities

### Monthly
- [ ] Update all dependencies
- [ ] Review user access
- [ ] Test backup restoration
- [ ] Review security policies
- [ ] Update documentation
- [ ] Rotate API keys (as needed)

### Quarterly
- [ ] Security audit
- [ ] Penetration testing
- [ ] Disaster recovery drill
- [ ] Compliance review
- [ ] Policy updates
- [ ] Team security training

### Annually
- [ ] Full security assessment
- [ ] Third-party audit
- [ ] Update incident response plan
- [ ] Review and update all policies
- [ ] Comprehensive penetration test
- [ ] Insurance policy review

## ✅ Sign-off

**Deployment Date:** _______________

**Reviewed By:**
- Security Lead: _______________ Date: _______________
- DevOps Lead: _______________ Date: _______________
- Technical Lead: _______________ Date: _______________

**Notes:**
```
[Add any specific notes, exceptions, or action items]
```

---

**⚠️ Important:** This checklist should be reviewed and updated regularly. Not all items may be applicable to your deployment, but each should be consciously evaluated.

**Last Updated:** 2024-12-16
