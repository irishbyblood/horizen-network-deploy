# Deployment Guide

This comprehensive guide covers the complete deployment process for the Horizen Network infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Server Setup](#server-setup)
- [Installation Steps](#installation-steps)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Post-Deployment](#post-deployment)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

#### Minimum Requirements
- **CPU**: 4 cores
- **RAM**: 8 GB
- **Storage**: 100 GB SSD
- **Network**: 100 Mbps

#### Recommended for Production
- **CPU**: 8 cores (or 4 cores with hyper-threading)
- **RAM**: 16 GB
- **Storage**: 500 GB SSD (NVMe preferred)
- **Network**: 1 Gbps

### Software Requirements

- **Operating System**: Ubuntu 22.04 LTS (recommended) or similar Linux distribution
- **Docker**: Version 24.0 or higher
- **Docker Compose**: Version 2.0 or higher
- **Git**: For repository management
- **OpenSSL**: For SSL certificate management

### Network Requirements

- Static IP address or DDNS service
- Domain name with DNS access
- Ports 80 (HTTP) and 443 (HTTPS) accessible from internet
- Firewall configured to allow necessary traffic

### DNS Requirements (Production Only)

**Before deploying to production, DNS must be configured:**

- Domain ownership: horizen-network.com (or your domain)
- DNS provider access (Cloudflare, AWS Route 53, GoDaddy, etc.)
- A record pointing domain to server IP
- CNAME records for all subdomains (www, druid, geniess, entity, api)
- DNS propagated globally (verify with https://www.whatsmydns.net/)

**📖 See [../dns/README.md](../dns/README.md) for complete DNS setup guide**

Quick DNS verification:
```bash
./dns/scripts/verify-dns.sh
```

## Server Setup

### 1. Update System

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget git vim
```

### 2. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify installation
docker --version
```

### 3. Install Docker Compose

Docker Compose is typically included with Docker Desktop, but for server installations:

```bash
# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Verify installation
docker compose version
```

### 4. Configure Firewall

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### 5. Configure System Limits

For optimal performance, especially for Druid:

```bash
# Edit limits.conf
sudo nano /etc/security/limits.conf

# Add the following lines:
* soft nofile 65535
* hard nofile 65535
* soft nproc 32768
* hard nproc 32768

# Edit sysctl.conf
sudo nano /etc/sysctl.conf

# Add the following lines:
vm.max_map_count=262144
vm.swappiness=10
net.core.somaxconn=65535

# Apply changes
sudo sysctl -p
```

## Installation Steps

### Step 1: Clone Repository

```bash
cd /opt
sudo git clone https://github.com/irishbyblood/horizen-network-deploy.git
sudo chown -R $USER:$USER horizen-network-deploy
cd horizen-network-deploy
```

### Step 2: Configure Environment

```bash
# Copy example environment file
cp .env.example .env

# Edit environment file
nano .env
```

### Step 3: Configure Required Variables

Edit `.env` and set the following required variables:

```env
# Domain Configuration
DOMAIN=your-domain.com
ADMIN_EMAIL=admin@your-domain.com

# Database Passwords (CHANGE THESE!)
POSTGRES_PASSWORD=your_secure_postgres_password
MONGO_PASSWORD=your_secure_mongo_password
REDIS_PASSWORD=your_secure_redis_password

# SSL Email
SSL_EMAIL=admin@your-domain.com
```

### Step 4: Review Configuration Files

Before deployment, review and customize:

1. **Nginx Configuration**: `nginx/conf.d/default.conf`
2. **Druid Configuration**: `druid/config/common.runtime.properties`
3. **Docker Compose**: `docker-compose.yml` and `docker-compose.prod.yml`

## Configuration

### Environment-Specific Configuration

#### Development Environment

For local development and testing:

```bash
# Deploy in development mode
./scripts/deploy.sh dev
```

Development mode includes:
- Exposed database ports for debugging
- Reduced resource limits
- Volume mounts for live reload
- Debug logging enabled

#### Production Environment

For production deployment:

```bash
# Deploy in production mode
./scripts/deploy.sh prod
```

Production mode includes:
- Resource limits and reservations
- Health checks enabled
- Restart policies configured
- Optimized settings

### Database Configuration

#### PostgreSQL (Druid Metadata)

Default configuration in `docker-compose.yml`:
- Database: `druid_metadata`
- User: `druid`
- Port: 5432 (internal)

#### MongoDB (Application Data)

Default configuration:
- Database: `horizen_network`
- User: `horizen`
- Port: 27017 (internal)

#### Redis (Caching)

Default configuration:
- Port: 6379 (internal)
- Password protected

### Druid Configuration

Druid is configured with the following services:

1. **Coordinator**: Manages data distribution
2. **Broker**: Handles queries
3. **Historical**: Serves historical data
4. **MiddleManager**: Processes indexing tasks
5. **Router**: Routes queries and provides UI

Configuration files located in `druid/config/`.

## Deployment

### Initial Deployment

```bash
# Make scripts executable (if not already)
chmod +x scripts/*.sh

# Deploy in production mode
./scripts/deploy.sh prod
```

The deployment script will:
1. Check prerequisites
2. Validate environment variables
3. Pull latest Docker images
4. Stop existing containers
5. Start all services
6. Perform health checks

### Verify Deployment

```bash
# Run health check
./scripts/health-check.sh

# Check container status
docker-compose ps

# View logs
docker-compose logs -f
```

### Access Services

After successful deployment:

- **Main Website**: `http://your-domain.com`
- **Druid Console**: `http://druid.your-domain.com`
- **Geniess**: `http://geniess.your-domain.com`

## Post-Deployment

### 1. Setup SSL Certificates

For production, enable HTTPS:

```bash
# Run SSL setup script
sudo ./scripts/ssl-setup.sh
```

This script will:
- Install Certbot
- Obtain SSL certificates from Let's Encrypt
- Configure Nginx for HTTPS
- Setup automatic renewal

### 2. Configure DNS

See [DNS_CONFIGURATION.md](DNS_CONFIGURATION.md) for detailed DNS setup instructions.

### 3. Setup Backups

Configure automated backups:

```bash
# Test backup
./scripts/backup.sh

# Add to crontab for daily backups at 2 AM
crontab -e

# Add this line:
0 2 * * * cd /opt/horizen-network-deploy && ./scripts/backup.sh >> /var/log/horizen-backup.log 2>&1
```

### 4. Configure Monitoring

Setup monitoring tools:

```bash
# View container stats
docker stats

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

### 5. Security Hardening

```bash
# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure fail2ban for SSH protection
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Troubleshooting

### Common Issues

#### 1. Containers Won't Start

**Problem**: Docker containers fail to start

**Solution**:
```bash
# Check logs
docker-compose logs [service_name]

# Check disk space
df -h

# Check memory
free -h

# Restart Docker
sudo systemctl restart docker
docker-compose up -d
```

#### 2. Nginx 502 Bad Gateway

**Problem**: Nginx shows 502 error when accessing services

**Solution**:
```bash
# Check if backend services are running
docker-compose ps

# Check Druid router logs
docker-compose logs druid-router

# Restart services
docker-compose restart druid-router nginx
```

#### 3. Druid Services Not Starting

**Problem**: Druid services fail to start or crash

**Solution**:
```bash
# Check ZooKeeper
docker-compose logs zookeeper

# Check PostgreSQL
docker-compose logs postgres

# Increase heap size in .env
DRUID_HEAP_SIZE=8g
DRUID_MAX_DIRECT_SIZE=8g

# Redeploy
docker-compose down
docker-compose up -d
```

#### 4. Database Connection Errors

**Problem**: Services cannot connect to databases

**Solution**:
```bash
# Test PostgreSQL
docker-compose exec postgres pg_isready -U druid

# Test MongoDB
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check network
docker network ls
docker network inspect horizen-network-deploy_horizen-network

# Recreate network
docker-compose down
docker-compose up -d
```

#### 5. SSL Certificate Issues

**Problem**: SSL certificates fail to generate or are invalid

**Solution**:
```bash
# Check DNS resolution
nslookup your-domain.com

# Check port 80 is accessible
sudo netstat -tulpn | grep :80

# Stop nginx temporarily
docker-compose stop nginx

# Try manual certificate generation
sudo certbot certonly --standalone -d your-domain.com

# Restart nginx
docker-compose start nginx
```

#### 6. High Memory Usage

**Problem**: System running out of memory

**Solution**:
```bash
# Check memory usage by container
docker stats --no-stream

# Reduce Druid heap sizes in .env
DRUID_HEAP_SIZE=2g
DRUID_MAX_DIRECT_SIZE=2g

# Enable swap if not already
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Redeploy with new settings
docker-compose down
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Getting Help

If you encounter issues not covered here:

1. Check the [README.md](../README.md)
2. Review [APPLICATION_SETUP.md](APPLICATION_SETUP.md) for app-specific issues
3. Check Docker logs: `docker-compose logs -f`
4. Review system logs: `sudo journalctl -xe`
5. Create an issue on GitHub with:
   - Error messages
   - System specifications
   - Steps to reproduce
   - Relevant log files

### Logs Location

- **Docker logs**: `docker-compose logs [service]`
- **Nginx logs**: Volume `nginx-logs`
- **Druid logs**: Volume `druid-data`
- **Backup logs**: `./backups/`
- **System logs**: `/var/log/`

### Maintenance Commands

```bash
# Update all images
docker-compose pull

# Cleanup unused resources
docker system prune -a

# View disk usage by container
docker system df

# Backup before maintenance
./scripts/backup.sh

# Update deployment
git pull origin main
./scripts/deploy.sh prod
```

## Next Steps

After successful deployment:

1. [Configure DNS](DNS_CONFIGURATION.md)
2. [Setup Applications](APPLICATION_SETUP.md)
3. Configure monitoring and alerting
4. Setup automated backups
5. Perform security audit
6. Load test the infrastructure

## Support

For additional support:
- Documentation: `/docs` directory
- Repository: https://github.com/irishbyblood/horizen-network-deploy
- Issues: Create a GitHub issue
