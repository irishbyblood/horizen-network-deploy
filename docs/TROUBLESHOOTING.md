# Troubleshooting Guide

This guide provides solutions to common issues encountered with the Horizen Network deployment.

## Table of Contents

- [General Issues](#general-issues)
- [Container Issues](#container-issues)
- [Database Issues](#database-issues)
- [Druid Issues](#druid-issues)
- [Network Issues](#network-issues)
- [Performance Issues](#performance-issues)
- [Backup and Recovery](#backup-and-recovery)
- [Monitoring and Alerts](#monitoring-and-alerts)

## General Issues

### Services Won't Start

**Symptoms**: Docker containers fail to start or immediately exit

**Diagnosis**:
```bash
# Check container status
docker-compose ps

# View recent logs
docker-compose logs --tail=50

# Check specific service
docker-compose logs [service-name]
```

**Solutions**:
1. Check disk space: `df -h`
2. Check memory: `free -h`
3. Verify environment variables: `cat .env`
4. Check Docker daemon: `sudo systemctl status docker`
5. Restart Docker: `sudo systemctl restart docker`

### Port Already in Use

**Symptoms**: Error "port is already allocated"

**Diagnosis**:
```bash
# Check what's using the port
sudo netstat -tulpn | grep :80
sudo lsof -i :80
```

**Solutions**:
```bash
# Stop conflicting service
sudo systemctl stop apache2  # or nginx

# Or change port in .env file
NGINX_HTTP_PORT=8080
```

### Permission Denied Errors

**Symptoms**: Cannot create directories or files

**Diagnosis**:
```bash
# Check ownership
ls -la

# Check current user
whoami
```

**Solutions**:
```bash
# Fix ownership
sudo chown -R $USER:$USER /opt/horizen-network-deploy

# Fix permissions
chmod +x scripts/*.sh
```

## Container Issues

### Container Keeps Restarting

**Diagnosis**:
```bash
# Check restart count
docker ps -a

# View logs
docker logs [container-name]

# Check container events
docker events --filter container=[container-name]
```

**Solutions**:
1. Check resource limits
2. Review application logs
3. Verify configuration files
4. Check dependencies (database connections)

### Container Out of Memory

**Symptoms**: Container killed by OOM (Out of Memory)

**Diagnosis**:
```bash
# Check memory usage
docker stats --no-stream

# Check OOM events
dmesg | grep -i "out of memory"
```

**Solutions**:
```bash
# Increase memory limits in docker-compose.yml
services:
  druid-broker:
    mem_limit: 8g
    memswap_limit: 8g

# Or adjust heap size in .env
DRUID_HEAP_SIZE=6g
```

### Container Network Issues

**Symptoms**: Containers cannot communicate

**Diagnosis**:
```bash
# Check network
docker network ls
docker network inspect horizen-network-deploy_horizen-network

# Test connectivity
docker-compose exec nginx ping postgres
```

**Solutions**:
```bash
# Recreate network
docker-compose down
docker-compose up -d

# Or reset Docker networking
sudo systemctl restart docker
```

## Database Issues

### PostgreSQL Connection Refused

**Symptoms**: "connection refused" errors

**Diagnosis**:
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check PostgreSQL logs
docker-compose logs postgres

# Test connection
docker-compose exec postgres pg_isready -U druid
```

**Solutions**:
```bash
# Restart PostgreSQL
docker-compose restart postgres

# Check credentials in .env
# Verify POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB

# Reset database (caution: data loss)
docker-compose down -v
docker-compose up -d postgres
```

### MongoDB Authentication Failed

**Symptoms**: Authentication failed errors

**Diagnosis**:
```bash
# Check MongoDB logs
docker-compose logs mongodb

# Test connection
docker-compose exec mongodb mongosh --username $MONGO_USER --password $MONGO_PASSWORD
```

**Solutions**:
```bash
# Verify credentials in .env

# Recreate MongoDB with correct credentials
docker-compose stop mongodb
docker volume rm horizen-network-deploy_mongodb-data
docker-compose up -d mongodb
```

### Redis Connection Timeout

**Symptoms**: Redis connection timeouts

**Diagnosis**:
```bash
# Check Redis
docker-compose exec redis redis-cli -a $REDIS_PASSWORD ping

# Check Redis logs
docker-compose logs redis
```

**Solutions**:
```bash
# Restart Redis
docker-compose restart redis

# Clear Redis cache
docker-compose exec redis redis-cli -a $REDIS_PASSWORD FLUSHALL

# Check Redis memory
docker-compose exec redis redis-cli -a $REDIS_PASSWORD INFO memory
```

## Druid Issues

### Druid Services Not Starting

**Symptoms**: Druid containers start but services don't respond

**Diagnosis**:
```bash
# Check all Druid services
for service in coordinator broker router historical middlemanager; do
  echo "Checking druid-$service..."
  docker-compose logs druid-$service | tail -20
done

# Check ZooKeeper
docker-compose exec zookeeper zkServer.sh status
```

**Solutions**:
1. **ZooKeeper Issues**:
   ```bash
   docker-compose restart zookeeper
   sleep 10
   docker-compose restart druid-coordinator druid-broker
   ```

2. **Memory Issues**:
   ```bash
   # Reduce heap size in .env
   DRUID_HEAP_SIZE=2g
   DRUID_MAX_DIRECT_SIZE=2g
   ```

3. **Metadata Issues**:
   ```bash
   # Check PostgreSQL connectivity
   docker-compose exec druid-coordinator curl -s http://localhost:8081/status
   ```

### Druid Queries Failing

**Symptoms**: Queries return errors or timeout

**Diagnosis**:
```bash
# Check broker status
curl http://localhost:8082/status

# Check segment availability
curl http://localhost:8081/druid/coordinator/v1/datasources

# View query logs
docker-compose logs druid-broker | grep -i error
```

**Solutions**:
```bash
# Restart broker
docker-compose restart druid-broker

# Check segment loading
curl http://localhost:8081/druid/coordinator/v1/loadstatus

# Verify datasource
curl http://localhost:8082/druid/v2/datasources
```

### Druid Ingestion Failing

**Symptoms**: Data ingestion tasks fail

**Diagnosis**:
```bash
# Check MiddleManager logs
docker-compose logs druid-middlemanager

# Check task status
curl http://localhost:8081/druid/indexer/v1/tasks

# Check overlord
docker-compose logs druid-coordinator | grep overlord
```

**Solutions**:
```bash
# Increase task capacity
# Edit druid/config/middlemanager/runtime.properties
druid.worker.capacity=5

# Restart MiddleManager
docker-compose restart druid-middlemanager
```

## Network Issues

### Cannot Access Services Externally

**Symptoms**: Services work internally but not externally

**Diagnosis**:
```bash
# Check if ports are open
sudo netstat -tulpn | grep :80

# Check firewall
sudo ufw status

# Test locally
curl -I http://localhost/
```

**Solutions**:
```bash
# Open firewall ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check Nginx configuration
docker-compose exec nginx nginx -t

# Restart Nginx
docker-compose restart nginx
```

### SSL Certificate Issues

**Symptoms**: SSL certificate errors or expired

**Diagnosis**:
```bash
# Check certificate expiry
echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates

# Check cert files
ls -la /etc/letsencrypt/live/$DOMAIN/
```

**Solutions**:
```bash
# Renew certificate
sudo certbot renew

# Or run SSL setup
sudo ./scripts/ssl-setup.sh

# Force renewal
sudo certbot renew --force-renewal
```

### DNS Not Resolving

**Symptoms**: Domain doesn't resolve to server

**Diagnosis**:
```bash
# Check DNS
dig $DOMAIN
nslookup $DOMAIN

# Check from different DNS
dig @8.8.8.8 $DOMAIN
```

**Solutions**:
```bash
# Verify DNS records in your provider
# Wait for DNS propagation (up to 48 hours)
# Check nameservers
dig NS $DOMAIN
```

## Performance Issues

### High CPU Usage

**Diagnosis**:
```bash
# Check overall usage
top

# Check container usage
docker stats

# Identify culprit
ps aux --sort=-%cpu | head -10
```

**Solutions**:
```bash
# Reduce Druid processing threads
# Edit .env
DRUID_PROCESSING_NUM_THREADS=1

# Limit container CPU
# Edit docker-compose.yml
services:
  druid-broker:
    cpus: '2.0'
```

### High Memory Usage

**Diagnosis**:
```bash
# Check memory
free -h

# Check swap
swapon --show

# Check container memory
docker stats --no-stream
```

**Solutions**:
```bash
# Reduce heap sizes
DRUID_HEAP_SIZE=2g

# Enable swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Restart services
docker-compose restart
```

### Slow Query Performance

**Diagnosis**:
```bash
# Check query time
time curl -X POST http://localhost:8082/druid/v2/sql -H "Content-Type: application/json" -d '{"query":"SELECT COUNT(*) FROM datasource"}'

# Check segment count
curl http://localhost:8081/druid/coordinator/v1/datasources/[datasource]/segments
```

**Solutions**:
```bash
# Increase cache size
# Edit druid config
druid.cache.sizeInBytes=2147483648

# Add more historical nodes
# Or increase processing power

# Optimize queries
# Use time filters
# Reduce granularity
```

## Backup and Recovery

### Backup Fails

**Diagnosis**:
```bash
# Check backup script
./scripts/backup.sh

# Check logs
tail -f backups/backup_*.log

# Check disk space
df -h
```

**Solutions**:
```bash
# Ensure sufficient disk space
# Check database connectivity
docker-compose exec postgres pg_isready

# Run backup manually
./scripts/backup.sh
```

### Restore Fails

**Diagnosis**:
```bash
# Verify backup file
gunzip -t backup.sql.gz

# Check database is running
docker-compose ps postgres
```

**Solutions**:
```bash
# Manual restore
gunzip -c backup.sql.gz | docker-compose exec -T postgres psql -U druid -d druid_metadata

# Use rollback script
./scripts/rollback.sh --backup backups/postgres_latest.sql.gz
```

## Monitoring and Alerts

### Alerts Not Firing

**Diagnosis**:
```bash
# Check Prometheus
curl http://localhost:9090/-/healthy

# Check AlertManager
curl http://localhost:9093/-/healthy

# Verify alert rules
cat monitoring/alerts.yml
```

**Solutions**:
```bash
# Restart monitoring stack
docker-compose restart prometheus alertmanager

# Verify configuration
docker-compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Notifications Not Sending

**Diagnosis**:
```bash
# Test notification script
./scripts/notify.sh "test" "Test message"

# Check webhook URLs in .env
echo $SLACK_WEBHOOK_URL
```

**Solutions**:
```bash
# Verify webhook URLs are correct
# Test with curl
curl -X POST -H 'Content-type: application/json' --data '{"text":"Test"}' $SLACK_WEBHOOK_URL

# Check logs
./scripts/notify.sh "test" "Test" 2>&1
```

## Getting More Help

If issues persist:

1. **Check Logs**: Always check relevant logs first
2. **Run Validation**: `./scripts/validate.sh`
3. **Run Health Check**: `./scripts/health-check.sh --verbose`
4. **Run Tests**: `./scripts/test.sh`
5. **Check GitHub Issues**: Search for similar problems
6. **Create Issue**: Provide logs, system info, and steps to reproduce

### Useful Commands for Debugging

```bash
# Complete health check
./scripts/health-check.sh --verbose

# System information
uname -a
docker --version
docker-compose --version

# Container inspection
docker inspect [container-name]

# Network debugging
docker network inspect horizen-network-deploy_horizen-network

# Volume inspection
docker volume ls
docker volume inspect [volume-name]

# Complete restart
docker-compose down
docker-compose up -d
./scripts/health-check.sh
```
