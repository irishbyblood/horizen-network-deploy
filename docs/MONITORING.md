# Monitoring Guide

Comprehensive monitoring setup for the Horizen Network using Prometheus, Grafana, and AlertManager.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Setup](#setup)
- [Metrics](#metrics)
- [Dashboards](#dashboards)
- [Alerts](#alerts)
- [Best Practices](#best-practices)

## Overview

The Horizen Network monitoring stack includes:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and notification
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Monitoring Stack                      │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐   ┌───────────┐ │
│  │   Grafana    │◄───│  Prometheus  │◄──│  Targets  │ │
│  │ (Port 3000)  │    │ (Port 9090)  │   │           │ │
│  └──────────────┘    └───────┬──────┘   └───────────┘ │
│                              │                          │
│                              ▼                          │
│                      ┌───────────────┐                  │
│                      │ AlertManager  │                  │
│                      │  (Port 9093)  │                  │
│                      └───────┬───────┘                  │
│                              │                          │
│                              ▼                          │
│                   ┌─────────────────────┐              │
│                   │   Notifications     │              │
│                   │ Slack/Email/Discord │              │
│                   └─────────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Setup

### 1. Deploy Monitoring Stack

Using Docker Compose (already configured):

```bash
# Monitoring services are included in docker-compose.yml
docker-compose up -d prometheus grafana alertmanager
```

### 2. Access Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (default credentials: admin/admin)
- **AlertManager**: http://localhost:9093

### 3. Configure Grafana

#### Initial Setup

1. Access Grafana at http://localhost:3000
2. Login with default credentials (admin/admin)
3. Change password when prompted
4. Add Prometheus as a data source:
   - Navigate to Configuration > Data Sources
   - Click "Add data source"
   - Select "Prometheus"
   - URL: `http://prometheus:9090`
   - Click "Save & Test"

#### Import Dashboards

1. Navigate to Dashboards > Import
2. Use dashboard IDs or upload JSON files:
   - **Node Exporter**: Dashboard ID 1860
   - **Docker Containers**: Dashboard ID 193
   - **Druid**: Use custom dashboard from `monitoring/dashboards/druid-dashboard.json`

### 4. Configure Alerts

Alerts are defined in `monitoring/alerts.yml` and automatically loaded by Prometheus.

To modify alerts:
```bash
# Edit alerts
nano monitoring/alerts.yml

# Reload Prometheus configuration
docker-compose exec prometheus kill -HUP 1
# Or restart
docker-compose restart prometheus
```

## Metrics

### System Metrics (Node Exporter)

- **CPU Usage**: `node_cpu_seconds_total`
- **Memory Usage**: `node_memory_MemAvailable_bytes`, `node_memory_MemTotal_bytes`
- **Disk Usage**: `node_filesystem_avail_bytes`, `node_filesystem_size_bytes`
- **Network Traffic**: `node_network_receive_bytes_total`, `node_network_transmit_bytes_total`

### Container Metrics (cAdvisor)

- **Container CPU**: `container_cpu_usage_seconds_total`
- **Container Memory**: `container_memory_usage_bytes`
- **Container Network**: `container_network_receive_bytes_total`
- **Container Restarts**: `container_start_time_seconds`

### Application Metrics

#### Nginx
- **Requests**: `nginx_http_requests_total`
- **Connections**: `nginx_connections_active`
- **Response Codes**: `nginx_http_requests_total{status="200"}`

#### Druid
- **Query Count**: `druid_query_count`
- **Query Time**: `druid_query_time`
- **Segment Count**: `druid_segment_count`
- **Ingestion Rate**: `druid_ingestion_rate`

#### PostgreSQL
- **Connections**: `pg_stat_database_numbackends`
- **Transactions**: `pg_stat_database_xact_commit`, `pg_stat_database_xact_rollback`
- **Locks**: `pg_locks_count`

#### MongoDB
- **Connections**: `mongodb_connections`
- **Operations**: `mongodb_op_counters_total`
- **Storage**: `mongodb_storage_size_bytes`

#### Redis
- **Memory**: `redis_memory_used_bytes`
- **Commands**: `redis_commands_processed_total`
- **Connections**: `redis_connected_clients`

### Custom Metrics

To add custom metrics, expose them from your application and configure Prometheus to scrape them.

Example Prometheus configuration:
```yaml
scrape_configs:
  - job_name: 'custom-app'
    static_configs:
      - targets: ['custom-app:9100']
```

## Dashboards

### Pre-built Dashboards

Located in `monitoring/dashboards/`:

1. **druid-dashboard.json**: Comprehensive Druid monitoring
2. **system-overview.json**: System resource monitoring
3. **container-metrics.json**: Docker container monitoring
4. **nginx-dashboard.json**: Nginx performance monitoring

### Creating Custom Dashboards

1. In Grafana, click "+" > "Dashboard"
2. Add panels with PromQL queries
3. Example queries:

```promql
# CPU usage by container
rate(container_cpu_usage_seconds_total{name=~"horizen-.*"}[5m]) * 100

# Memory usage by container
container_memory_usage_bytes{name=~"horizen-.*"} / 1024 / 1024 / 1024

# Druid query latency (95th percentile)
histogram_quantile(0.95, rate(druid_query_time_bucket[5m]))

# HTTP request rate
rate(nginx_http_requests_total[5m])

# Database connections
sum(pg_stat_database_numbackends) by (datname)
```

4. Save dashboard and export as JSON for backup

### Dashboard Best Practices

- Group related metrics together
- Use consistent time ranges
- Add helpful descriptions to panels
- Set appropriate refresh intervals
- Configure alert thresholds on panels

## Alerts

### Alert Rules

Comprehensive alert rules are defined in `monitoring/alerts.yml` covering:

1. **Service Availability**
   - Container down
   - Service unhealthy
   - High error rates

2. **Resource Utilization**
   - High CPU usage (>80%)
   - High memory usage (>90%)
   - Low disk space (<10%)

3. **Performance**
   - Slow query times
   - High latency
   - Low throughput

4. **Security**
   - Failed login attempts
   - Unauthorized access
   - Certificate expiration

5. **Data Integrity**
   - Backup failures
   - Data inconsistencies
   - Replication lag

### Alert Severity Levels

- **Critical**: Immediate action required (service down, data loss risk)
- **Warning**: Attention needed (high resource usage, degraded performance)
- **Info**: Informational (successful operations, maintenance events)

### Notification Channels

Configure AlertManager to send notifications via:

#### Slack
```yaml
# alertmanager.yml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'YOUR_SLACK_WEBHOOK_URL'
        channel: '#alerts'
        title: 'Horizen Network Alert'
```

#### Email
```yaml
receivers:
  - name: 'email'
    email_configs:
      - to: 'admin@horizen-network.com'
        from: 'alerts@horizen-network.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'alerts@horizen-network.com'
        auth_password: 'PASSWORD'
```

#### Discord
```yaml
receivers:
  - name: 'discord'
    webhook_configs:
      - url: 'YOUR_DISCORD_WEBHOOK_URL'
```

### Testing Alerts

```bash
# Trigger test alert
curl -X POST http://localhost:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "This is a test alert"
    }
  }]'

# Or use notification script
./scripts/notify.sh "test" "Test alert message"
```

## Best Practices

### 1. Metric Collection

- **Sample rate**: 15s for critical services, 30s for others
- **Retention**: 15 days for detailed metrics, 90 days for aggregated
- **Cardinality**: Avoid high-cardinality labels

### 2. Dashboard Design

- Start with overview dashboard
- Drill-down into component-specific dashboards
- Use consistent color schemes
- Add helpful annotations

### 3. Alert Management

- Avoid alert fatigue (too many alerts)
- Set appropriate thresholds
- Use alert grouping
- Document response procedures
- Regular alert review and tuning

### 4. Performance Optimization

```yaml
# Prometheus configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

# Reduce retention if disk space is limited
storage:
  tsdb:
    retention.time: 15d
    retention.size: 50GB
```

### 5. Security

- Enable authentication in Grafana
- Use HTTPS for production
- Restrict Prometheus access
- Regular security updates

### 6. Backup and Recovery

```bash
# Backup Prometheus data
tar -czf prometheus-backup.tar.gz /var/lib/prometheus

# Backup Grafana dashboards
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/search | \
  jq -r '.[] | .uid' | \
  xargs -I {} curl -H "Authorization: Bearer YOUR_API_KEY" \
    http://localhost:3000/api/dashboards/uid/{} > dashboard-{}.json
```

## Monitoring Checklist

- [ ] Prometheus collecting metrics from all targets
- [ ] Grafana dashboards configured and accessible
- [ ] AlertManager routing configured
- [ ] Notification channels tested
- [ ] Alert rules reviewed and tested
- [ ] Dashboard backups scheduled
- [ ] Monitoring system itself is monitored
- [ ] Documentation updated
- [ ] Team trained on monitoring tools
- [ ] On-call procedures documented

## Troubleshooting

### Prometheus Not Collecting Metrics

```bash
# Check Prometheus logs
docker-compose logs prometheus

# Check targets
curl http://localhost:9090/api/v1/targets

# Test scrape endpoint
curl http://target:9100/metrics
```

### Grafana Connection Issues

```bash
# Check Grafana logs
docker-compose logs grafana

# Verify Prometheus data source
curl -u admin:admin http://localhost:3000/api/datasources
```

### Alerts Not Firing

```bash
# Check alert rules
curl http://localhost:9090/api/v1/rules

# Check AlertManager
curl http://localhost:9093/api/v1/alerts

# View AlertManager logs
docker-compose logs alertmanager
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Support

For monitoring-related issues:
- Check logs: `docker-compose logs prometheus grafana alertmanager`
- Review configuration files in `monitoring/`
- Run health checks: `./scripts/health-check.sh`
- Create GitHub issue with monitoring-specific label
