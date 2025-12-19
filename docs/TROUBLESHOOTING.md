# Troubleshooting Guide

This comprehensive guide covers common issues and their solutions for the Horizen Network infrastructure.

## Table of Contents

- [General Issues](#general-issues)
- [Docker and Container Issues](#docker-and-container-issues)
- [Network and Connectivity Issues](#network-and-connectivity-issues)
- [Database Issues](#database-issues)
- [Druid-Specific Issues](#druid-specific-issues)
- [Performance Issues](#performance-issues)
- [SSL/TLS Issues](#ssltls-issues)
- [Backup and Recovery Issues](#backup-and-recovery-issues)
- [Deployment Issues](#deployment-issues)

## General Issues

### Service Not Responding

**Symptoms**: Service appears to be running but doesn't respond to requests

**Diagnosis**:
```bash
# Check container status
docker-compose ps

# Check container logs
docker-compose logs [service_name]

# Check if service is listening on expected port
docker-compose exec [service_name] netstat -tulpn
```

**Solutions**:
```bash
# Restart the specific service
docker-compose restart [service_name]

# If that doesn't work, recreate the container
docker-compose up -d --force-recreate [service_name]

# Check for port conflicts
sudo netstat -tulpn | grep [port_number]
```

### Health Check Failures

**Symptoms**: `./scripts/health-check.sh` reports errors

**Diagnosis**:
```bash
# Run health check with verbose output
bash -x ./scripts/health-check.sh

# Check individual services manually
curl -I http://localhost/health
docker exec horizen-postgres pg_isready
docker exec horizen-redis redis-cli -a $REDIS_PASSWORD ping
```

**Solutions**:
```bash
# Wait for services to fully start (they may still be initializing)
sleep 60 && ./scripts/health-check.sh

# Check logs for specific failing service
docker-compose logs [failing_service]

# Restart all services
docker-compose restart
```

### Environment Variables Not Loading

**Symptoms**: Services fail to start with configuration errors

**Diagnosis**:
```bash
# Verify .env file exists
ls -la .env

# Check environment variables are loaded
docker-compose config | grep -i password

# Verify variable syntax
cat .env | grep -v "^#" | grep "="
```

**Solutions**:
```bash
# Ensure .env file has correct format (no spaces around =)
# BAD:  PASSWORD = secret
# GOOD: PASSWORD=secret

# Reload environment variables
docker-compose down
source .env
docker-compose up -d

# Check for special characters that need escaping
# Wrap values with special characters in quotes
REDIS_PASSWORD="my!pass@word#here"
```

## Docker and Container Issues

### Containers Keep Restarting

**Symptoms**: Container status shows "Restarting" continuously

**Diagnosis**:
```bash
# Check container logs
docker-compose logs --tail=100 [service_name]

# Inspect container for exit code
docker inspect [container_name] | grep -A 10 State

# Check resource usage
docker stats --no-stream
```

**Solutions**:
```bash
# Common cause: Out of memory
# Solution: Increase memory allocation or reduce heap sizes
# Edit .env:
DRUID_HEAP_SIZE=4g  # Reduce if necessary

# Common cause: Missing dependencies
# Solution: Recreate containers
docker-compose down
docker-compose pull
docker-compose up -d

# Common cause: Permission issues
# Solution: Check volume permissions
sudo chown -R 999:999 ./volumes/postgres
sudo chown -R 1000:1000 ./volumes/druid
```

### Docker Compose Command Not Found

**Symptoms**: `docker-compose` or `docker compose` command not available

**Solutions**:
```bash
# Check which version you have
docker compose version  # Plugin version (Docker Compose V2)
docker-compose version  # Standalone version (Docker Compose V1)

# Install Docker Compose plugin (recommended)
sudo apt-get update
sudo apt-get install docker-compose-plugin

# Or install standalone version
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Volume Mount Errors

**Symptoms**: Containers fail to start with "no such file or directory" errors

**Diagnosis**:
```bash
# Check if directories exist
ls -la ./druid
ls -la ./nginx
ls -la ./volumes

# Check volume definitions
docker-compose config | grep -A 5 volumes
```

**Solutions**:
```bash
# Create missing directories
mkdir -p ./volumes/postgres
mkdir -p ./volumes/mongodb
mkdir -p ./volumes/redis
mkdir -p ./volumes/druid

# Fix permissions
chmod -R 755 ./volumes

# Remove old volumes and recreate
docker-compose down -v
docker volume prune -f
docker-compose up -d
```

### Image Pull Failures

**Symptoms**: Cannot pull Docker images

**Diagnosis**:
```bash
# Test Docker Hub connectivity
docker pull hello-world

# Check disk space
df -h

# Check Docker daemon
sudo systemctl status docker
```

**Solutions**:
```bash
# Restart Docker daemon
sudo systemctl restart docker

# Clear Docker cache
docker system prune -a

# Use alternative registry if Docker Hub is blocked
# Edit docker-compose.yml to use mirror
```

## Network and Connectivity Issues

### Cannot Access Services Externally

**Symptoms**: Services work on localhost but not from external IPs

**Diagnosis**:
```bash
# Check if ports are bound to correct interface
sudo netstat -tulpn | grep -E ':(80|443|8888)'

# Test from server itself
curl -I http://localhost

# Check firewall rules
sudo ufw status
sudo iptables -L -n
```

**Solutions**:
```bash
# Open firewall ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Check Nginx is listening on 0.0.0.0, not 127.0.0.1
docker-compose exec nginx cat /etc/nginx/nginx.conf | grep listen

# Verify DNS is pointing to correct IP
dig +short horizen-network.com
```

### DNS Resolution Failures

**Symptoms**: Cannot resolve domain names from within containers

**Diagnosis**:
```bash
# Test DNS from container
docker-compose exec nginx nslookup google.com
docker-compose exec nginx cat /etc/resolv.conf

# Check Docker DNS settings
docker network inspect horizen-network-deploy_horizen-network
```

**Solutions**:
```bash
# Add DNS servers to Docker daemon
sudo nano /etc/docker/daemon.json
# Add:
{
  "dns": ["8.8.8.8", "1.1.1.1"]
}

# Restart Docker
sudo systemctl restart docker
docker-compose up -d

# Or add DNS to docker-compose.yml for specific service
services:
  service_name:
    dns:
      - 8.8.8.8
      - 1.1.1.1
```

### Port Conflicts

**Symptoms**: Cannot bind to port, "address already in use" errors

**Diagnosis**:
```bash
# Find what's using the port
sudo lsof -i :80
sudo netstat -tulpn | grep :80

# Check Docker port mappings
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Solutions**:
```bash
# Stop conflicting service
sudo systemctl stop apache2  # If Apache is running
sudo systemctl stop nginx    # If system Nginx is running

# Change port in .env file
NGINX_HTTP_PORT=8080
NGINX_HTTPS_PORT=8443

# Then restart
docker-compose down
docker-compose up -d
```

### Inter-Container Communication Failures

**Symptoms**: Containers cannot communicate with each other

**Diagnosis**:
```bash
# Check network connectivity
docker-compose exec druid-broker ping postgres

# Verify network configuration
docker network ls
docker network inspect horizen-network-deploy_horizen-network

# Check container names resolution
docker-compose exec druid-broker nslookup postgres
```

**Solutions**:
```bash
# Recreate network
docker-compose down
docker network prune
docker-compose up -d

# Ensure all services are on same network
# Check docker-compose.yml has:
networks:
  horizen-network:
    driver: bridge

# Each service should have:
services:
  service_name:
    networks:
      - horizen-network
```

## Database Issues

### PostgreSQL Connection Refused

**Symptoms**: Applications cannot connect to PostgreSQL

**Diagnosis**:
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
docker-compose exec postgres pg_isready -U druid

# Check logs
docker-compose logs postgres | tail -50

# Verify credentials
docker-compose exec postgres psql -U druid -d druid_metadata -c "SELECT 1;"
```

**Solutions**:
```bash
# Verify environment variables
cat .env | grep POSTGRES

# Reset PostgreSQL password
docker-compose exec postgres psql -U postgres
ALTER USER druid WITH PASSWORD 'new_password';
\q

# Update .env with new password
POSTGRES_PASSWORD=new_password

# Restart services that depend on PostgreSQL
docker-compose restart druid-coordinator druid-broker
```

### MongoDB Authentication Failed

**Symptoms**: Cannot connect to MongoDB with credentials

**Diagnosis**:
```bash
# Check MongoDB is running
docker-compose ps mongodb

# Test connection without auth
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"

# Check logs
docker-compose logs mongodb | grep -i auth
```

**Solutions**:
```bash
# Connect as admin to reset password
docker-compose exec mongodb mongosh admin
use admin
db.changeUserPassword("horizen", "new_password")
exit

# Update .env
MONGO_PASSWORD=new_password

# Restart dependent services
docker-compose restart
```

### Redis Connection Issues

**Symptoms**: Applications cannot connect to Redis

**Diagnosis**:
```bash
# Test Redis
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Check if password is required
docker-compose exec redis redis-cli ping

# Check logs
docker-compose logs redis
```

**Solutions**:
```bash
# If password is wrong, connect without auth and set new one
docker-compose exec redis redis-cli
CONFIG SET requirepass "new_password"
exit

# Update .env
REDIS_PASSWORD=new_password

# Restart services
docker-compose restart
```

### Database Out of Space

**Symptoms**: Database operations fail with "no space left on device"

**Diagnosis**:
```bash
# Check disk usage
df -h

# Check Docker volume usage
docker system df

# Check specific volume size
docker volume inspect horizen-network-deploy_postgres-data
```

**Solutions**:
```bash
# Clean up old data
# For PostgreSQL
docker-compose exec postgres psql -U druid -d druid_metadata
VACUUM FULL;
\q

# Clean Docker system
docker system prune -a --volumes

# Increase disk size (cloud provider)
# Then resize filesystem
sudo resize2fs /dev/sda1

# Move volumes to larger disk
# Stop services
docker-compose down
# Move data
sudo rsync -av /var/lib/docker/volumes/ /new/location/
# Update Docker data-root
sudo nano /etc/docker/daemon.json
# Add: "data-root": "/new/location"
sudo systemctl restart docker
docker-compose up -d
```

## Druid-Specific Issues

### Druid Services Won't Start

**Symptoms**: Druid coordinator, broker, or other services fail to start

**Diagnosis**:
```bash
# Check logs for each service
docker-compose logs druid-coordinator
docker-compose logs druid-broker
docker-compose logs druid-router

# Check dependencies (ZooKeeper, PostgreSQL)
docker-compose ps zookeeper postgres

# Check memory allocation
free -h
docker stats
```

**Solutions**:
```bash
# Common cause: Insufficient memory
# Reduce heap sizes in .env
DRUID_HEAP_SIZE=2g
DRUID_MAX_DIRECT_SIZE=2g

# Common cause: ZooKeeper not ready
# Wait for ZooKeeper to be healthy
docker-compose logs zookeeper | grep -i "binding to port"
# Then restart Druid services
docker-compose restart druid-coordinator druid-broker

# Common cause: PostgreSQL metadata not initialized
# Check if tables exist
docker-compose exec postgres psql -U druid -d druid_metadata
\dt
\q
```

### Druid Query Performance Issues

**Symptoms**: Queries are slow or timing out

**Diagnosis**:
```bash
# Check broker logs for slow queries
docker-compose logs druid-broker | grep -i "slow"

# Check cluster status in Druid console
# Navigate to: http://localhost:8888

# Check segment loading
docker-compose logs druid-historical | grep -i segment

# Monitor resource usage
docker stats druid-broker druid-historical
```

**Solutions**:
```bash
# Increase processing threads
# Edit .env
DRUID_PROCESSING_NUM_THREADS=4

# Increase buffer size
DRUID_PROCESSING_BUFFER_SIZE=1073741824

# Enable caching
# Edit druid/config/common.runtime.properties
druid.broker.cache.useCache=true
druid.broker.cache.populateCache=true

# Restart services
docker-compose restart druid-broker druid-historical

# Optimize queries
# Use time filters
# Limit result set size
# Use appropriate granularity
```

### Druid Data Ingestion Failures

**Symptoms**: Data ingestion tasks fail or hang

**Diagnosis**:
```bash
# Check MiddleManager logs
docker-compose logs druid-middlemanager

# Check task status via API
curl http://localhost:8081/druid/indexer/v1/tasks

# Check available resources
docker stats druid-middlemanager
```

**Solutions**:
```bash
# Increase MiddleManager resources
# Edit .env
DRUID_MIDDLEMANAGER_HEAP_SIZE=2g

# Check input data format
# Ensure JSON/CSV format is correct

# Retry failed tasks
curl -X POST http://localhost:8081/druid/indexer/v1/task/{taskId}/shutdown

# Check for schema mismatches
# Verify dimensionsSpec and metricsSpec in ingestion spec
```

### Druid Segments Not Loading

**Symptoms**: Historical nodes not loading segments

**Diagnosis**:
```bash
# Check Historical logs
docker-compose logs druid-historical | grep -i segment

# Check segment availability
curl http://localhost:8081/druid/coordinator/v1/segments

# Check deep storage configuration
docker-compose exec druid-coordinator cat /opt/druid/conf/druid/cluster/_common/common.runtime.properties | grep storage
```

**Solutions**:
```bash
# Verify deep storage is accessible
# For local storage
ls -la /opt/druid/var/druid/segments

# Force segment reload
curl -X POST http://localhost:8081/druid/coordinator/v1/rules/_default

# Check Historical capacity
curl http://localhost:8083/druid/historical/v1/loadstatus

# Restart Historical
docker-compose restart druid-historical
```

## Performance Issues

### High CPU Usage

**Symptoms**: System or container CPU usage consistently above 80%

**Diagnosis**:
```bash
# Check top processes
top -b -n 1 | head -20

# Check container CPU usage
docker stats --no-stream

# Check specific service
docker-compose exec [service] top -b -n 1
```

**Solutions**:
```bash
# For Druid: Reduce processing threads
DRUID_PROCESSING_NUM_THREADS=2

# For queries: Optimize and add indexes
# For databases: Add appropriate indexes

# Limit container CPU
# Add to docker-compose.yml:
services:
  service_name:
    deploy:
      resources:
        limits:
          cpus: '2'

# Scale horizontally
# Add more Historical nodes for Druid
# Add read replicas for databases
```

### High Memory Usage

**Symptoms**: System running out of memory, OOM kills

**Diagnosis**:
```bash
# Check memory usage
free -h

# Check swap usage
swapon --show

# Check which container is using most memory
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}"

# Check for memory leaks
docker-compose logs [service] | grep -i "OutOfMemory"
```

**Solutions**:
```bash
# Add swap space
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Reduce Druid heap sizes
DRUID_HEAP_SIZE=4g
DRUID_MAX_DIRECT_SIZE=4g

# Set container memory limits
# Add to docker-compose.yml:
services:
  service_name:
    deploy:
      resources:
        limits:
          memory: 4G

# Clear caches
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches

# Restart services with new limits
docker-compose down
docker-compose up -d
```

### Slow Network Performance

**Symptoms**: High latency, slow data transfer

**Diagnosis**:
```bash
# Check network usage
iftop

# Check for packet loss
ping -c 100 8.8.8.8 | grep loss

# Check bandwidth
iperf3 -s  # On server
iperf3 -c server_ip  # On client

# Check Docker network
docker network inspect horizen-network-deploy_horizen-network
```

**Solutions**:
```bash
# Optimize network settings
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216'
sudo sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216'

# Make permanent
sudo nano /etc/sysctl.conf
# Add the above settings

# Check for DDoS/high traffic
sudo netstat -ntu | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -n

# Enable Cloudflare or CDN
# Configure in DNS settings
```

## SSL/TLS Issues

### Let's Encrypt Certificate Generation Failed

**Symptoms**: SSL setup script fails to obtain certificates

**Diagnosis**:
```bash
# Check DNS propagation
dig +short horizen-network.com
nslookup horizen-network.com

# Check port 80 is accessible
curl -I http://horizen-network.com

# Check Certbot logs
sudo cat /var/log/letsencrypt/letsencrypt.log
```

**Solutions**:
```bash
# Ensure DNS is fully propagated (wait 24 hours if needed)

# Ensure port 80 is open and forwarded
sudo ufw allow 80/tcp
sudo ufw reload

# Stop Nginx temporarily
docker-compose stop nginx

# Try manual certificate generation
sudo certbot certonly --standalone -d horizen-network.com -d www.horizen-network.com --email admin@horizen-network.com

# If successful, restart Nginx
docker-compose start nginx

# Check rate limits
# Let's Encrypt: 50 certificates per registered domain per week
# If hit limit, wait or use staging environment
certbot certonly --dry-run --standalone -d horizen-network.com
```

### Certificate Expired or About to Expire

**Symptoms**: Browser shows certificate expired warning

**Diagnosis**:
```bash
# Check certificate expiration
echo | openssl s_client -connect horizen-network.com:443 -servername horizen-network.com 2>/dev/null | openssl x509 -noout -dates

# Check Certbot renewal status
sudo certbot certificates
```

**Solutions**:
```bash
# Renew certificate manually
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run

# Ensure automatic renewal is configured
sudo systemctl status certbot.timer

# Enable automatic renewal if not active
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Force renewal (if less than 30 days to expiration)
sudo certbot renew --force-renewal

# Reload Nginx after renewal
docker-compose exec nginx nginx -s reload
```

### Mixed Content Warnings

**Symptoms**: Browser shows "not secure" despite HTTPS

**Diagnosis**:
```bash
# Check for HTTP resources in HTTPS page
# Open browser developer tools
# Check console for mixed content warnings

# Verify Nginx SSL configuration
docker-compose exec nginx cat /etc/nginx/conf.d/ssl.conf
```

**Solutions**:
```bash
# Update all URLs to use HTTPS or protocol-relative URLs
# Change: http://example.com/script.js
# To:     https://example.com/script.js
# Or:     //example.com/script.js

# Add HSTS header to force HTTPS
# Edit nginx/conf.d/ssl.conf
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Reload Nginx
docker-compose exec nginx nginx -s reload
```

## Backup and Recovery Issues

### Backup Script Fails

**Symptoms**: `./scripts/backup.sh` exits with errors

**Diagnosis**:
```bash
# Run backup script with debug output
bash -x ./scripts/backup.sh

# Check disk space
df -h

# Check permissions
ls -la ./backups

# Check database connectivity
docker-compose ps postgres mongodb
```

**Solutions**:
```bash
# Create backup directory if missing
mkdir -p ./backups
chmod 755 ./backups

# Fix permissions
sudo chown -R $USER:$USER ./backups

# Ensure databases are running
docker-compose up -d postgres mongodb

# Check and increase disk space if needed
# Clean old backups
find ./backups -name "*.tar.gz" -mtime +30 -delete
```

### Restore Fails

**Symptoms**: Cannot restore from backup

**Diagnosis**:
```bash
# Verify backup file integrity
tar -tzf backups/backup_YYYYMMDD_HHMMSS.tar.gz

# Check backup file size
ls -lh backups/

# Test database connection
docker-compose exec postgres pg_isready
```

**Solutions**:
```bash
# For PostgreSQL restore
docker-compose exec -T postgres psql -U druid -d druid_metadata < backups/postgres_backup.sql

# For MongoDB restore
docker-compose exec -T mongodb mongorestore --username=horizen --password=$MONGO_PASSWORD --authenticationDatabase=admin --db=horizen_network /backup/mongodb/

# If restore partially fails
# Drop and recreate database
docker-compose exec postgres psql -U postgres
DROP DATABASE druid_metadata;
CREATE DATABASE druid_metadata OWNER druid;
\q

# Then try restore again
```

### S3 Upload Fails

**Symptoms**: Backup uploads to S3 fail in CI/CD

**Diagnosis**:
```bash
# Test AWS CLI
aws s3 ls

# Check credentials
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY

# Test upload manually
aws s3 cp test.txt s3://your-bucket/test.txt
```

**Solutions**:
```bash
# Verify AWS credentials in GitHub Secrets
# Ensure IAM user has proper permissions:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-bucket/*",
        "arn:aws:s3:::your-bucket"
      ]
    }
  ]
}

# Check bucket policy and CORS if needed
# Ensure bucket exists and region is correct
```

## Deployment Issues

### Deployment Script Fails

**Symptoms**: `./scripts/deploy.sh` exits with errors

**Diagnosis**:
```bash
# Run with debug output
bash -x ./scripts/deploy.sh prod

# Check Docker is running
sudo systemctl status docker

# Check docker-compose file validity
docker-compose config
```

**Solutions**:
```bash
# Ensure .env file exists
cp .env.example .env
nano .env  # Fill in required values

# Fix Docker Compose file syntax
# Validate with:
docker-compose config

# Ensure scripts are executable
chmod +x scripts/*.sh

# Check system resources
free -h
df -h

# Clean up if needed
docker system prune -a
```

### GitHub Actions Deployment Fails

**Symptoms**: CI/CD pipeline fails during deployment

**Diagnosis**:
```bash
# Check GitHub Actions logs
# Go to repository → Actions → Failed workflow

# Verify SSH connection
ssh -i private_key user@server

# Check server disk space and resources
df -h
free -h
```

**Solutions**:
```bash
# Verify GitHub Secrets are set correctly
# Required secrets:
# - PRODUCTION_HOST
# - PRODUCTION_USERNAME
# - PRODUCTION_SSH_KEY
# - STAGING_HOST
# - STAGING_USERNAME
# - STAGING_SSH_KEY

# Verify SSH key format (should be private key)
# Ensure key doesn't have passphrase

# Check server has git and docker installed
ssh user@server 'which git docker'

# Increase timeout in workflow if needed
# Add to .github/workflows/deploy.yml:
timeout-minutes: 30
```

## Getting Additional Help

If your issue is not covered here:

1. **Check Logs**: Always start with logs
   ```bash
   docker-compose logs [service_name]
   sudo journalctl -xe
   tail -f /var/log/syslog
   ```

2. **Search Documentation**:
   - [Docker Documentation](https://docs.docker.com/)
   - [Apache Druid Documentation](https://druid.apache.org/docs/latest/)
   - [Nginx Documentation](https://nginx.org/en/docs/)

3. **Community Resources**:
   - Stack Overflow
   - Docker Community Forums
   - Apache Druid User Group

4. **Create an Issue**:
   - Go to GitHub repository
   - Create new issue with:
     - Error messages
     - Steps to reproduce
     - System information
     - Relevant logs

## Emergency Procedures

### Complete System Failure

```bash
# Stop all services
docker-compose down

# Check system health
df -h
free -h
top

# Clear Docker system
docker system prune -a --volumes

# Restore from backup
./scripts/restore.sh

# Start fresh
docker-compose up -d

# Monitor startup
docker-compose logs -f
```

### Data Corruption

```bash
# Stop affected service
docker-compose stop [service]

# Restore from latest backup
# See DEPLOYMENT_GUIDE.md for restore procedures

# Verify data integrity
docker-compose exec postgres psql -U druid -d druid_metadata
# Run integrity checks

# Restart service
docker-compose start [service]
```

### Security Breach

```bash
# Immediately isolate system
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow 22/tcp  # Keep SSH only

# Change all passwords
# Update .env file with new credentials

# Check for unauthorized access
sudo last
sudo lastb
grep "Failed password" /var/log/auth.log

# Review Docker logs for suspicious activity
docker-compose logs | grep -i "error\|fail\|unauthorized"

# Contact security team
# Follow SECURITY.md procedures
```

---

**Last Updated**: December 2024

For additional support, refer to the [README.md](../README.md) and [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md).
