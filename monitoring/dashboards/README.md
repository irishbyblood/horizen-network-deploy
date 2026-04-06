# Grafana Dashboards

This directory contains pre-configured Grafana dashboards for monitoring the Horizen Network infrastructure.

## Available Dashboards

### 1. horizen-overview.json
**Comprehensive overview dashboard**

Displays:
- Service health status
- Resource utilization (CPU, Memory, Disk)
- Container metrics
- Network traffic
- Active connections

Use this as your primary monitoring dashboard.

### 2. Custom Dashboards (Coming Soon)
- `druid-detailed.json` - In-depth Druid cluster monitoring
- `nginx-performance.json` - Nginx request and response metrics
- `database-metrics.json` - PostgreSQL and MongoDB performance
- `security-dashboard.json` - Security events and failed logins

## Importing Dashboards

### Method 1: Grafana UI

1. Access Grafana at http://localhost:3000
2. Navigate to **Dashboards** > **Import**
3. Click **Upload JSON file**
4. Select dashboard JSON file
5. Choose Prometheus as data source
6. Click **Import**

### Method 2: API

```bash
# Import dashboard via API
curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @horizen-overview.json
```

### Method 3: Docker Volume Mount

Add to your `docker-compose.yml`:

```yaml
grafana:
  volumes:
    - ./monitoring/dashboards:/etc/grafana/provisioning/dashboards
```

Create provisioning file `monitoring/dashboards/dashboard.yml`:

```yaml
apiVersion: 1

providers:
  - name: 'Horizen Dashboards'
    orgId: 1
    folder: 'Horizen Network'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

## Community Dashboards

You can also import popular community dashboards:

### Node Exporter Full
**Dashboard ID**: 1860

Shows comprehensive system metrics from Node Exporter.

```bash
# Import by ID
Grafana UI > Import > Dashboard ID: 1860
```

### Docker Container & Host Metrics
**Dashboard ID**: 193

Container-specific metrics and resource usage.

```bash
# Import by ID
Grafana UI > Import > Dashboard ID: 193
```

### Prometheus Stats
**Dashboard ID**: 2

Monitor Prometheus itself.

```bash
# Import by ID
Grafana UI > Import > Dashboard ID: 2
```

## Creating Custom Dashboards

### Step 1: Plan Your Dashboard

Decide what you want to monitor:
- Which services?
- What metrics?
- What time ranges?
- What alert thresholds?

### Step 2: Useful PromQL Queries

```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total{name=~"horizen-.*"}[5m]) * 100

# Container memory usage (MB)
container_memory_usage_bytes{name=~"horizen-.*"} / 1024 / 1024

# Druid query rate
rate(druid_query_count[5m])

# HTTP request rate
rate(nginx_http_requests_total[5m])

# Error rate
rate(nginx_http_requests_total{status=~"5.."}[5m])

# Database connections
pg_stat_database_numbackends

# Disk usage percentage
(node_filesystem_size_bytes - node_filesystem_avail_bytes) / node_filesystem_size_bytes * 100
```

### Step 3: Create in Grafana

1. Click **+** > **Dashboard**
2. Add panels with your queries
3. Configure visualization (Graph, Gauge, Stat, etc.)
4. Set alert thresholds
5. Save dashboard
6. Export as JSON

### Step 4: Export and Save

```bash
# Export dashboard
curl -H "Authorization: Bearer YOUR_API_KEY" \
  http://localhost:3000/api/dashboards/uid/horizen-overview > horizen-overview.json

# Backup all dashboards
for uid in $(curl -s http://admin:admin@localhost:3000/api/search | jq -r '.[].uid'); do
  curl -H "Authorization: Bearer YOUR_API_KEY" \
    http://localhost:3000/api/dashboards/uid/$uid > dashboard-$uid.json
done
```

## Dashboard Best Practices

### Design Guidelines

1. **Start with Overview**: Create a high-level dashboard first
2. **Drill-Down Pattern**: Link to detailed dashboards
3. **Consistent Layout**: Keep similar metrics together
4. **Color Coding**: Use consistent colors (green=good, red=bad)
5. **Time Ranges**: Default to last 6 hours, allow customization

### Panel Best Practices

1. **Descriptive Titles**: Clear, concise panel titles
2. **Units**: Always specify units (%, MB, req/s)
3. **Legends**: Include helpful legend information
4. **Thresholds**: Set warning and critical thresholds
5. **Tooltips**: Add descriptions for complex metrics

### Performance Optimization

1. **Query Optimization**: Use efficient PromQL
2. **Time Range**: Don't query too far back
3. **Sample Interval**: Match Prometheus scrape interval
4. **Panel Count**: Limit to 20-30 panels per dashboard
5. **Auto-Refresh**: Use 30s or 1m intervals

## Dashboard Variables

Use variables to make dashboards dynamic:

```json
{
  "templating": {
    "list": [
      {
        "name": "service",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(up, job)"
      },
      {
        "name": "instance",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(up{job=\"$service\"}, instance)"
      }
    ]
  }
}
```

Use in queries: `up{job="$service", instance="$instance"}`

## Alerts on Dashboards

Add alert rules to panels:

1. Edit panel
2. Click **Alert** tab
3. Configure alert conditions
4. Set notification channels
5. Save

Example alert:
- **Condition**: WHEN avg() OF query(A, 5m, now) IS ABOVE 80
- **Notification**: Send to Slack channel

## Troubleshooting

### Dashboard not loading
```bash
# Check Grafana logs
docker-compose logs grafana

# Verify Prometheus connection
curl http://localhost:3000/api/health
```

### Metrics not showing
```bash
# Check Prometheus
curl http://localhost:9090/api/v1/targets

# Test query
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Dashboard lost after restart
- Export dashboards regularly
- Use provisioning for persistence
- Store in version control

## Backup and Restore

### Backup Dashboards

```bash
# Backup all dashboards
./scripts/backup-dashboards.sh

# Or manually
mkdir -p backups/dashboards
for file in monitoring/dashboards/*.json; do
  cp "$file" backups/dashboards/
done
```

### Restore Dashboards

```bash
# Via API
for file in backups/dashboards/*.json; do
  curl -X POST http://admin:admin@localhost:3000/api/dashboards/db \
    -H "Content-Type: application/json" \
    -d @"$file"
done

# Via UI
Import each JSON file through Grafana UI
```

## Additional Resources

- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Community Dashboards](https://grafana.com/grafana/dashboards/)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/)

## Support

For dashboard-related issues:
- Check Grafana logs: `docker-compose logs grafana`
- Verify Prometheus connectivity
- Review dashboard JSON for errors
- Create GitHub issue with dashboard label
