# Monitoring Guide

This guide covers the setup and configuration of monitoring and observability for the Horizen Network infrastructure.

## Table of Contents

- [Overview](#overview)
- [Monitoring Stack](#monitoring-stack)
- [Prometheus Setup](#prometheus-setup)
- [Alertmanager Configuration](#alertmanager-configuration)
- [Grafana Setup](#grafana-setup)
- [Log Aggregation](#log-aggregation)
- [Metrics Collection](#metrics-collection)
- [Dashboards](#dashboards)
- [Alerting](#alerting)
- [Best Practices](#best-practices)

## Overview

The Horizen Network uses a comprehensive monitoring stack to ensure system health, performance, and reliability.

### Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Data Sources                             │
├─────────────────────────────────────────────────────────────┤
│  Nginx │ Druid │ PostgreSQL │ MongoDB │ Redis │ System    │
└────┬─────┬──────┬──────────┬──────────┬───────┬───────────┘
     │     │      │          │          │       │
     └─────┴──────┴──────────┴──────────┴───────┘
                      │
          ┌───────────▼───────────┐
          │     Exporters         │
          ├───────────────────────┤
          │ node-exporter         │
          │ postgres-exporter     │
          │ mongodb-exporter      │
          │ redis-exporter        │
          │ nginx-exporter        │
          │ cadvisor             │
          └───────────┬───────────┘
                      │
          ┌───────────▼───────────┐
          │     Prometheus        │
          │  (Metrics Storage)    │
          └───────────┬───────────┘
                      │
          ┌───────────┴───────────┐
          │                       │
    ┌─────▼──────┐      ┌────────▼────────┐
    │ Alertmanager│      │    Grafana      │
    │ (Alerting)  │      │(Visualization) │
    └─────┬──────┘      └────────┬────────┘
          │                       │
          ▼                       ▼
    Slack/Email             Dashboards
```

## Monitoring Stack

### Components

1. **Prometheus**: Time-series database for metrics
2. **Alertmanager**: Alert routing and notification
3. **Grafana**: Visualization and dashboards
4. **Node Exporter**: System metrics
5. **cAdvisor**: Container metrics
6. **Service Exporters**: Database and application metrics

### Quick Start

The monitoring stack is configured in `docker-compose.yml`. To enable monitoring:

```bash
# Start all services including monitoring
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Access monitoring interfaces
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3000
# Alertmanager: http://localhost:9093
```

## Prometheus Setup

### Configuration

Prometheus configuration is located in `monitoring/prometheus.yml`.

### Key Configuration Sections

```yaml
global:
  scrape_interval: 15s      # How often to scrape targets
  evaluation_interval: 15s  # How often to evaluate rules

scrape_configs:
  # Add your scrape configurations
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:9113']
```

### Adding New Scrape Targets

Edit `monitoring/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'my-service'
    static_configs:
      - targets: ['my-service:9100']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: 'my-service'
```

### Querying Metrics

Access Prometheus UI at `http://localhost:9090`

**Example Queries**:

```promql
# CPU usage
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100

# HTTP request rate
rate(nginx_http_requests_total[5m])

# Druid query latency
histogram_quantile(0.95, rate(druid_query_time_bucket[5m]))
```

### Recording Rules

Create recording rules for frequently used queries:

```yaml
# Add to monitoring/rules.yml
groups:
  - name: aggregate_metrics
    interval: 30s
    rules:
      - record: instance:cpu_usage:rate5m
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
      
      - record: instance:memory_usage:ratio
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes
```

## Alertmanager Configuration

### Setup

Configuration is in `monitoring/alertmanager.yml`.

### Alert Routing

```yaml
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  
  routes:
    # Critical alerts to pagerduty and slack
    - match:
        severity: critical
      receiver: 'critical-alerts'
      continue: true
    
    # Warning alerts to slack only
    - match:
        severity: warning
      receiver: 'warning-alerts'
```

### Notification Receivers

#### Slack Integration

```yaml
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### Email Integration

```yaml
receivers:
  - name: 'email-notifications'
    email_configs:
      - to: 'alerts@horizen-network.com'
        from: 'prometheus@horizen-network.com'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'prometheus@horizen-network.com'
        auth_password: 'your-app-password'
        headers:
          Subject: '[Horizen Network] {{ .GroupLabels.alertname }}'
```

#### PagerDuty Integration

```yaml
receivers:
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
        description: '{{ .GroupLabels.alertname }}'
```

### Testing Alerts

```bash
# Send test alert
curl -H "Content-Type: application/json" -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning"
  },
  "annotations": {
    "summary": "This is a test alert"
  }
}]' http://localhost:9093/api/v1/alerts

# Check Alertmanager status
curl http://localhost:9093/api/v1/status

# View active alerts
curl http://localhost:9093/api/v1/alerts
```

## Grafana Setup

### Initial Setup

1. **Access Grafana**: http://localhost:3000
2. **Default Credentials**: 
   - Username: `admin`
   - Password: `admin` (change on first login)

### Add Prometheus Data Source

1. Navigate to Configuration → Data Sources
2. Click "Add data source"
3. Select "Prometheus"
4. Configure:
   ```
   Name: Prometheus
   URL: http://prometheus:9090
   Access: Server (default)
   ```
5. Click "Save & Test"

### Importing Dashboards

#### Pre-built Dashboards

Import community dashboards from [Grafana.com](https://grafana.com/grafana/dashboards/):

1. Navigate to Dashboards → Import
2. Enter dashboard ID:
   - **Node Exporter Full**: 1860
   - **Docker Container Metrics**: 193
   - **Nginx Overview**: 12708
   - **PostgreSQL Database**: 9628
   - **Redis Dashboard**: 763
   - **Druid Dashboard**: Custom (see below)

3. Select Prometheus data source
4. Click "Import"

### Creating Custom Dashboards

#### Dashboard Structure

```json
{
  "dashboard": {
    "title": "Horizen Network Overview",
    "tags": ["horizen", "overview"],
    "timezone": "browser",
    "panels": [
      {
        "title": "CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "{{ instance }}"
          }
        ]
      }
    ]
  }
}
```

#### Panel Examples

**CPU Usage Panel**:
```
Query: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
Visualization: Time Series
Legend: {{ instance }}
Unit: Percent (0-100)
Thresholds: Warning 80, Critical 95
```

**Memory Usage Panel**:
```
Query: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100
Visualization: Gauge
Unit: Percent (0-100)
Thresholds: Warning 80, Critical 95
```

**HTTP Request Rate**:
```
Query: rate(nginx_http_requests_total[5m])
Visualization: Time Series
Legend: {{ status }}
Unit: requests/sec
```

### Dashboard Best Practices

1. **Organize by Service**: Create separate dashboards for each major component
2. **Use Variables**: Make dashboards flexible with template variables
3. **Set Appropriate Refresh**: 5s for real-time, 1m for normal monitoring
4. **Add Annotations**: Mark deployments and incidents
5. **Use Thresholds**: Visual indicators for warning and critical levels

## Log Aggregation

### Docker Logging Configuration

Configure in `docker-compose.yml`:

```yaml
services:
  service_name:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

### Centralized Logging with ELK Stack

#### Setup Filebeat

```yaml
# filebeat.yml
filebeat.inputs:
  - type: docker
    containers.ids:
      - '*'

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  
output.logstash:
  hosts: ["logstash:5044"]
```

#### Setup Logstash

```ruby
# logstash.conf
input {
  beats {
    port => 5044
  }
}

filter {
  json {
    source => "message"
  }
  
  date {
    match => ["timestamp", "ISO8601"]
    target => "@timestamp"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "horizen-logs-%{+YYYY.MM.dd}"
  }
}
```

### Viewing Logs

```bash
# View logs for specific service
docker-compose logs -f nginx

# View logs with timestamps
docker-compose logs -t nginx

# View last 100 lines
docker-compose logs --tail=100 nginx

# View logs from specific time
docker-compose logs --since 2024-01-01T00:00:00 nginx

# Search logs
docker-compose logs nginx | grep ERROR
```

### Log Rotation

System log rotation:

```bash
# Create logrotate config
sudo nano /etc/logrotate.d/docker-containers

# Add configuration
/var/lib/docker/containers/*/*.log {
  daily
  rotate 7
  compress
  missingok
  delaycompress
  copytruncate
}

# Test configuration
sudo logrotate -d /etc/logrotate.d/docker-containers

# Force rotation
sudo logrotate -f /etc/logrotate.d/docker-containers
```

## Metrics Collection

### System Metrics (Node Exporter)

Metrics available at `http://localhost:9100/metrics`

**Key Metrics**:
- `node_cpu_seconds_total`: CPU usage
- `node_memory_MemAvailable_bytes`: Available memory
- `node_filesystem_avail_bytes`: Available disk space
- `node_network_receive_bytes_total`: Network received
- `node_network_transmit_bytes_total`: Network transmitted

### Container Metrics (cAdvisor)

Metrics available at `http://localhost:8080/metrics`

**Key Metrics**:
- `container_cpu_usage_seconds_total`: Container CPU
- `container_memory_usage_bytes`: Container memory
- `container_network_receive_bytes_total`: Container network
- `container_fs_usage_bytes`: Container filesystem

### Application Metrics

#### Druid Metrics

```bash
# Coordinator status
curl http://localhost:8081/status

# Broker status
curl http://localhost:8082/status

# Query metrics
curl http://localhost:8082/druid/v2/sql -H "Content-Type: application/json" \
  -d '{"query":"SELECT * FROM sys.segments"}'
```

#### Custom Application Metrics

Expose metrics in Prometheus format:

```python
# Python example
from prometheus_client import start_http_server, Counter, Histogram
import time

# Create metrics
requests_total = Counter('app_requests_total', 'Total requests')
request_duration = Histogram('app_request_duration_seconds', 'Request duration')

# Expose metrics
start_http_server(8000)

# Use in application
requests_total.inc()
with request_duration.time():
    # Your code here
    pass
```

## Dashboards

### Essential Dashboards

#### 1. Infrastructure Overview Dashboard

**Panels**:
- System CPU usage
- System memory usage
- System disk usage
- Network traffic
- Container status
- Service availability

#### 2. Druid Performance Dashboard

**Panels**:
- Query latency (p50, p95, p99)
- Query throughput
- Segment availability
- JVM memory usage
- GC frequency
- Data ingestion rate

#### 3. Database Dashboard

**Panels**:
- Connection count
- Query throughput
- Query latency
- Cache hit rate
- Disk I/O
- Replication lag (if applicable)

#### 4. Application Dashboard

**Panels**:
- Request rate
- Response time
- Error rate
- Active connections
- Queue depth

### Dashboard Variables

Create reusable dashboards with variables:

```
Name: instance
Type: Query
Query: label_values(up, instance)
Multi-value: true
Include All option: true
```

Use in queries:
```promql
up{instance=~"$instance"}
```

## Alerting

### Alert Rules

Alert rules are defined in `monitoring/alerts.yml`. See the comprehensive alert rules already configured.

### Alert Priority Levels

**Critical**: Immediate action required
- Service down
- High error rate (>5%)
- Resource exhaustion

**Warning**: Attention needed
- High resource usage (>80%)
- Performance degradation
- Certificate expiring soon

**Info**: Informational only
- Deployment notifications
- Scheduled maintenance

### Alert Management

#### Silencing Alerts

```bash
# Create silence via API
curl -X POST http://localhost:9093/api/v1/silences -H "Content-Type: application/json" -d '{
  "matchers": [
    {
      "name": "alertname",
      "value": "NginxDown",
      "isRegex": false
    }
  ],
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": "2024-01-01T01:00:00Z",
  "createdBy": "admin",
  "comment": "Maintenance window"
}'

# List active silences
curl http://localhost:9093/api/v1/silences

# Delete silence
curl -X DELETE http://localhost:9093/api/v1/silence/{silence_id}
```

#### Alert Inhibition

Prevent redundant alerts:

```yaml
# In alertmanager.yml
inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
```

## Best Practices

### Monitoring Best Practices

1. **Monitor the Monitors**: Ensure monitoring stack is healthy
2. **Set Appropriate Thresholds**: Avoid alert fatigue
3. **Use SLOs/SLIs**: Define and monitor Service Level Objectives
4. **Alert on Symptoms**: Not just causes
5. **Document Runbooks**: Link alerts to resolution procedures
6. **Regular Review**: Update dashboards and alerts based on learnings

### Alert Best Practices

1. **Make Alerts Actionable**: Every alert should require action
2. **Include Context**: Add relevant information in annotations
3. **Avoid Alert Fatigue**: Don't over-alert
4. **Use Proper Routing**: Send to appropriate channels
5. **Test Regularly**: Verify alert delivery works

### Performance Best Practices

1. **Limit Metric Retention**: Based on needs (30-90 days typical)
2. **Use Recording Rules**: Pre-compute expensive queries
3. **Optimize Queries**: Use appropriate time ranges and functions
4. **Monitor Prometheus**: Track Prometheus itself
5. **Regular Cleanup**: Remove unused metrics and dashboards

### Security Best Practices

1. **Enable Authentication**: Secure Grafana, Prometheus, and Alertmanager
2. **Use HTTPS**: For web interfaces
3. **Limit Access**: Network policies and firewall rules
4. **Audit Access**: Monitor who accesses monitoring
5. **Protect Secrets**: Use secret management for credentials

## Troubleshooting Monitoring

### Prometheus Not Scraping

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# View Prometheus logs
docker-compose logs prometheus

# Test endpoint manually
curl http://nginx:9113/metrics
```

### High Prometheus Memory Usage

```bash
# Check retention settings
# Edit prometheus.yml
storage:
  tsdb:
    retention.time: 30d
    retention.size: 50GB

# Restart Prometheus
docker-compose restart prometheus
```

### Grafana Dashboard Not Loading

```bash
# Check Grafana logs
docker-compose logs grafana

# Verify data source connection
curl http://localhost:3000/api/datasources

# Check Prometheus is reachable from Grafana
docker-compose exec grafana curl http://prometheus:9090/api/v1/query?query=up
```

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Support

For monitoring-related issues:
1. Check logs: `docker-compose logs prometheus grafana alertmanager`
2. Verify configuration: `docker-compose config`
3. Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. Create GitHub issue with monitoring details

---

**Last Updated**: December 2024
