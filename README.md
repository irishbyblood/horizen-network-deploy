# Horizen Network - Complete Deployment Infrastructure

![Horizen Network](https://img.shields.io/badge/Status-Active-green)
![License](https://img.shields.io/badge/License-Public%20Domain-blue)
![Docker](https://img.shields.io/badge/Docker-Required-blue)

## 🌐 Overview

Horizen Network is a comprehensive deployment infrastructure for hosting advanced data analytics and intelligence platforms. This repository contains all configuration files, documentation, scripts, and infrastructure-as-code needed to deploy a production-ready website along with Apache Druid and Geniess applications.

## ✨ Features

- **Real-Time Analytics**: Apache Druid for fast slice-and-dice analytics on large datasets
- **Enterprise Intelligence**: Geniess application for advanced data processing
- **Docker Infrastructure**: Complete containerized deployment with Docker Compose
- **Nginx Reverse Proxy**: High-performance web server and reverse proxy
- **Automated Deployment**: Scripts for deployment, backup, SSL setup, and health checks
- **Production Ready**: Separate configurations for development and production environments
- **Security Focused**: SSL/TLS support, security headers, and best practices

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Nginx (Reverse Proxy)                    │
│                    Port 80 (HTTP) / 443 (HTTPS)                 │
└───────────┬────────────────┬────────────────┬────────────────────┘
            │                │                │
            ▼                ▼                ▼
    ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
    │   Website    │  │ Druid Router │  │   Geniess    │
    │ (Static HTML)│  │   :8888      │  │  (External)  │
    └──────────────┘  └──────┬───────┘  └──────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
       ┌────────────┐ ┌────────────┐ ┌────────────┐
       │Coordinator │ │   Broker   │ │ Historical │
       │   :8081    │ │   :8082    │ │   :8083    │
       └─────┬──────┘ └──────┬─────┘ └──────┬─────┘
             │                │              │
             └────────┬───────┴──────────────┘
                      ▼
          ┌──────────────────────────┐
          │     Infrastructure       │
          ├──────────────────────────┤
          │  PostgreSQL (Metadata)   │
          │  ZooKeeper (Coordination)│
          │  MongoDB (Application)   │
          │  Redis (Caching)         │
          └──────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- **Operating System**: Ubuntu 22.04 LTS or similar Linux distribution
- **Docker**: Version 24.0 or higher
- **Docker Compose**: Version 2.0 or higher
- **Server Resources**:
  - Minimum: 4 CPU cores, 8GB RAM, 100GB SSD
  - Recommended: 8 CPU cores, 16GB RAM, 500GB SSD

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/irishbyblood/horizen-network-deploy.git
   cd horizen-network-deploy
   ```

2. **Configure environment variables**:
   ```bash
   cp .env.example .env
   nano .env  # Edit with your configuration
   ```

3. **Configure DNS** (required for production):
   ```bash
   # Point your domain to your server IP
   # Add required DNS records (see dns/README.md)
   
   # Verify DNS configuration
   ./dns/scripts/verify-dns.sh
   ```
   
   See [DNS Configuration Guide](dns/README.md) for detailed instructions.

4. **Deploy the infrastructure**:
   ```bash
   # For development
   ./scripts/deploy.sh dev

   # For production
   ./scripts/deploy.sh prod
   ```

5. **Verify deployment**:
   ```bash
   ./scripts/health-check.sh
   ```

6. **Setup SSL certificates** (production only):
   ```bash
   sudo ./scripts/ssl-setup.sh
   ```

## 🌐 DNS Setup

Before deploying to production, configure DNS for your domain:

### Required DNS Records

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A | @ | YOUR_SERVER_IP | Main domain |
| CNAME | www | horizen-network.com | WWW redirect |
| CNAME | druid | horizen-network.com | Apache Druid UI |
| CNAME | geniess | horizen-network.com | Geniess AI platform |
| CNAME | entity | horizen-network.com | Entity unified AI app |
| CNAME | api | horizen-network.com | API endpoint |

### Quick Setup

```bash
# 1. Get your server IP
curl -4 ifconfig.me

# 2. Configure DNS records at your DNS provider
# (See dns/README.md for provider-specific guides)

# 3. Verify DNS configuration
./dns/scripts/verify-dns.sh

# 4. Wait for DNS propagation
# Check: https://www.whatsmydns.net/
```

### Automated Setup (Cloudflare)

```bash
export CLOUDFLARE_API_TOKEN="your_token"
export CLOUDFLARE_ZONE_ID="your_zone_id"
export SERVER_IP="your_server_ip"

./dns/scripts/setup-cloudflare.sh
```

**📖 Complete DNS Guide**: See [dns/README.md](dns/README.md) for comprehensive instructions, troubleshooting, and provider-specific guides.

## 📚 Documentation

Detailed documentation is available in the `docs/` directory:

- [**Deployment Guide**](docs/DEPLOYMENT_GUIDE.md) - Complete deployment instructions
- [**DNS Configuration**](docs/DNS_CONFIGURATION.md) - Basic DNS setup and configuration
- [**Application Setup**](docs/APPLICATION_SETUP.md) - Application-specific configurations

**New comprehensive DNS documentation** in `dns/` directory:

- [**DNS Setup Guide**](dns/README.md) - Complete DNS configuration guide
- [**DNS Records**](dns/RECORDS.md) - Detailed record specifications
- [**Provider Guides**](dns/providers/) - Cloudflare, GoDaddy, Namecheap, Route 53, DigitalOcean
- [**Verification Checklist**](dns/VERIFICATION_CHECKLIST.md) - Step-by-step verification
- [**Troubleshooting**](dns/TROUBLESHOOTING.md) - Common issues and solutions
- [**Migration Guide**](dns/MIGRATION.md) - Moving between DNS providers

## 🔧 Configuration

### Environment Variables

Key environment variables in `.env`:

```env
# Domain Configuration
DOMAIN=horizen-network.com
ADMIN_EMAIL=admin@horizen-network.com

# Database Credentials
POSTGRES_PASSWORD=your_secure_password
MONGO_PASSWORD=your_secure_password
REDIS_PASSWORD=your_secure_password

# Druid Configuration
DRUID_HEAP_SIZE=4g

# SSL Configuration
SSL_EMAIL=admin@horizen-network.com
```

### Docker Compose Profiles

- `docker-compose.yml` - Base configuration
- `docker-compose.dev.yml` - Development overrides (exposed ports, debug mode)
- `docker-compose.prod.yml` - Production overrides (resource limits, health checks)

## 🛠️ Management Scripts

### Deploy Script
```bash
./scripts/deploy.sh [dev|prod]
```
Performs full deployment with prerequisite checks, image pulls, and health verification.

### Backup Script
```bash
./scripts/backup.sh
```
Creates backups of all databases and configurations with automatic rotation.

### SSL Setup Script
```bash
sudo ./scripts/ssl-setup.sh
```
Obtains and configures SSL certificates using Let's Encrypt.

### Health Check Script
```bash
./scripts/health-check.sh
```
Verifies all services are running and healthy.

## 🌐 Accessing Services

After deployment, access your services at:

- **Main Website**: `http://horizen-network.com`
- **Druid Console**: `http://druid.horizen-network.com` or `http://horizen-network.com/druid`
- **Geniess**: `http://geniess.horizen-network.com`

### Development Mode Additional Ports

When running in development mode:
- Druid Router: `http://localhost:8888`
- Druid Coordinator: `http://localhost:8081`
- Druid Broker: `http://localhost:8082`
- PostgreSQL: `localhost:5432`
- MongoDB: `localhost:27017`
- Redis: `localhost:6379`

## 🔐 Security

- All secrets should be stored in `.env` file (not committed to Git)
- SSL/TLS certificates should be obtained before production deployment
- Default passwords must be changed before deployment
- Regular security updates should be applied
- See [SECURITY.md](SECURITY.md) for security policy and best practices

## 📦 Services Included

| Service | Description | Port |
|---------|-------------|------|
| Nginx | Web server and reverse proxy | 80, 443 |
| Apache Druid | Real-time analytics database | 8081-8083, 8888 |
| PostgreSQL | Metadata storage for Druid | 5432 |
| ZooKeeper | Coordination service | 2181 |
| MongoDB | Application database | 27017 |
| Redis | Caching layer | 6379 |

## 🐳 Docker Management

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### View Logs
```bash
docker-compose logs -f [service_name]
```

### Restart a Service
```bash
docker-compose restart [service_name]
```

## 📊 Monitoring

### Check Container Status
```bash
docker-compose ps
```

### View Resource Usage
```bash
docker stats
```

### Health Checks
```bash
./scripts/health-check.sh
```

## 🔄 Backup and Recovery

### Create Backup
```bash
./scripts/backup.sh
```

Backups are stored in `./backups/` and include:
- PostgreSQL database dumps
- MongoDB collections
- Druid segments
- Configuration files

### Restore from Backup
```bash
# PostgreSQL
docker-compose exec -T postgres psql -U druid < backups/postgres_YYYYMMDD_HHMMSS.sql

# MongoDB
docker-compose exec -T mongodb mongorestore --username=horizen --password=PASSWORD /backup
```

## 🧪 Testing

### Validate Docker Compose Files
```bash
docker-compose config
docker-compose -f docker-compose.yml -f docker-compose.prod.yml config
```

### Test Nginx Configuration
```bash
docker-compose exec nginx nginx -t
```

### Test Database Connections
```bash
# PostgreSQL
docker-compose exec postgres pg_isready

# MongoDB
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Redis
docker-compose exec redis redis-cli ping
```

## 🤝 Contributing

This repository is in the public domain. Feel free to use, modify, and distribute as needed.

## 📄 License

This project is released into the public domain under the Unlicense. See [LICENSE](LICENSE) for details.

## 🆘 Support

For issues and questions:
1. Check the [documentation](docs/)
2. Review existing issues
3. Create a new issue with detailed information

## 🗺️ Roadmap

- [x] Docker infrastructure
- [x] Nginx configuration
- [x] Apache Druid setup
- [x] Deployment scripts
- [x] Backup automation
- [ ] Kubernetes manifests
- [ ] CI/CD pipelines
- [ ] Monitoring dashboards
- [ ] Automated testing

## 📝 Changelog

### Version 1.0.0 (Initial Release)
- Complete Docker Compose infrastructure
- Nginx reverse proxy configuration
- Apache Druid multi-node setup
- PostgreSQL, MongoDB, Redis integration
- Automated deployment scripts
- SSL/TLS support
- Backup and recovery scripts
- Health check automation
- Comprehensive documentation

---

**Built with ❤️ for the Horizen Network**
