# Application Setup Guide

This guide covers the setup and configuration of Geniess and Apache Druid applications for the Horizen Network.

## Table of Contents

- [Apache Druid](#apache-druid)
- [Geniess Application](#geniess-application)
- [Integration](#integration)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Apache Druid

Apache Druid is a real-time analytics database designed for fast slice-and-dice analytics (OLAP queries) on large data sets.

### Requirements

#### Hardware Requirements
- **Minimum**:
  - CPU: 4 cores
  - RAM: 8 GB
  - Storage: 50 GB SSD
- **Recommended**:
  - CPU: 8 cores
  - RAM: 16 GB
  - Storage: 500 GB SSD (for deep storage)

#### Software Requirements
- Java 17 (included in Docker image)
- PostgreSQL 15+ (for metadata storage)
- ZooKeeper 3.8+ (for coordination)
- Linux OS (Ubuntu 22.04 recommended)

### Installation Steps

Druid is automatically installed via Docker Compose. The infrastructure includes:

1. **Coordinator**: Manages data availability and distribution
2. **Broker**: Routes queries and merges results
3. **Historical**: Serves immutable historical data
4. **MiddleManager**: Ingests new data
5. **Router**: Provides unified API and web console

### Initial Setup

#### 1. Verify Druid Services

```bash
# Check all Druid containers are running
docker-compose ps | grep druid

# Expected output:
# horizen-druid-coordinator
# horizen-druid-broker
# horizen-druid-router
# horizen-druid-historical
# horizen-druid-middlemanager
```

#### 2. Access Druid Console

Open your browser and navigate to:
- **Via subdomain**: `http://druid.horizen-network.com`
- **Via path**: `http://horizen-network.com/druid`
- **Direct (dev mode)**: `http://localhost:8888`

You should see the Druid web console with:
- Data sources
- Query interface
- Ingestion tasks
- Cluster status

#### 3. Verify Cluster Health

In the Druid console:

1. Navigate to **Services** tab
2. Verify all services are running:
   - Coordinator
   - Broker
   - Historical
   - MiddleManager
   - Router

### Configuration

#### Memory Configuration

Edit `.env` file to adjust Druid memory settings:

```env
# Development (8GB total RAM)
DRUID_HEAP_SIZE=2g
DRUID_MAX_DIRECT_SIZE=2g

# Production (16GB+ RAM)
DRUID_HEAP_SIZE=8g
DRUID_MAX_DIRECT_SIZE=8g
```

#### Processing Configuration

Edit `druid/config/common.runtime.properties`:

```properties
# Number of processing threads
druid.processing.numThreads=4

# Processing buffer size (per thread)
druid.processing.buffer.sizeBytes=1073741824

# Number of merge buffers
druid.processing.numMergeBuffers=4
```

#### Deep Storage Configuration

For production, configure cloud storage:

**AWS S3**:
```properties
druid.storage.type=s3
druid.storage.bucket=your-bucket-name
druid.storage.baseKey=druid/segments
druid.s3.accessKey=YOUR_ACCESS_KEY
druid.s3.secretKey=YOUR_SECRET_KEY
```

**Google Cloud Storage**:
```properties
druid.storage.type=google
druid.google.bucket=your-bucket-name
druid.google.prefix=druid/segments
```

**Azure**:
```properties
druid.storage.type=azure
druid.azure.account=your-account
druid.azure.key=YOUR_KEY
druid.azure.container=druid
```

### Data Ingestion

#### Batch Ingestion

1. Navigate to Druid console
2. Click **Load data**
3. Select data source (Local disk, S3, HTTP, etc.)
4. Follow the ingestion wizard

#### Streaming Ingestion (Kafka)

Configure Kafka integration in `druid/config/common.runtime.properties`:

```properties
druid.extensions.loadList=["druid-kafka-indexing-service"]
```

Create a Kafka supervisor:

```json
{
  "type": "kafka",
  "dataSchema": {
    "dataSource": "your-datasource",
    "timestampSpec": {
      "column": "timestamp",
      "format": "auto"
    },
    "dimensionsSpec": {
      "dimensions": ["dimension1", "dimension2"]
    },
    "metricsSpec": [
      {"type": "count", "name": "count"},
      {"type": "longSum", "name": "metric1", "fieldName": "metric1"}
    ]
  },
  "ioConfig": {
    "topic": "your-kafka-topic",
    "consumerProperties": {
      "bootstrap.servers": "kafka:9092"
    }
  }
}
```

#### SQL-based Ingestion

Use Druid SQL for ingestion:

```sql
INSERT INTO "your-datasource"
SELECT
  TIME_PARSE("timestamp") AS __time,
  dimension1,
  dimension2,
  metric1
FROM TABLE(
  EXTERN(
    '{"type":"http","uris":["https://example.com/data.json"]}',
    '{"type":"json"}',
    '[{"name":"timestamp","type":"string"},{"name":"dimension1","type":"string"}]'
  )
)
PARTITIONED BY DAY
```

### Querying Data

#### Native Queries

```json
{
  "queryType": "timeseries",
  "dataSource": "your-datasource",
  "intervals": ["2024-01-01/2024-12-31"],
  "granularity": "day",
  "aggregations": [
    {"type": "count", "name": "count"}
  ]
}
```

#### SQL Queries

```sql
SELECT
  TIME_FLOOR(__time, 'PT1H') AS hour,
  dimension1,
  SUM(metric1) AS total
FROM "your-datasource"
WHERE __time >= CURRENT_TIMESTAMP - INTERVAL '7' DAY
GROUP BY 1, 2
ORDER BY hour DESC
```

### Monitoring

Check Druid metrics:

```bash
# Coordinator metrics
curl http://localhost:8081/status

# Broker metrics
curl http://localhost:8082/status

# Query health
curl http://localhost:8082/druid/v2/sql -H "Content-Type: application/json" -d '{"query":"SELECT 1"}'
```

## Geniess Application

Geniess is an advanced intelligence and analytics platform designed for enterprise data processing.

### Requirements

#### Hardware Requirements (Windows Server)
- **Minimum**:
  - CPU: 4 cores
  - RAM: 8 GB
  - Storage: 100 GB
- **Recommended**:
  - CPU: 8+ cores
  - RAM: 16 GB
  - Storage: 500 GB SSD

#### Software Requirements
- **Operating System**: Windows Server 2019 or 2022
- **.NET Framework**: 4.5 or higher
- **SQL Server**: 2016 or higher (Express, Standard, or Enterprise)
- **IIS**: 10.0 or higher

### Installation Steps

#### 1. Prepare Windows Server

```powershell
# Install IIS
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# Install .NET Framework 4.8
# Download from: https://dotnet.microsoft.com/download/dotnet-framework/net48

# Install SQL Server
# Download from: https://www.microsoft.com/en-us/sql-server/sql-server-downloads
```

#### 2. Install SQL Server

1. Download SQL Server installer
2. Choose **Basic** installation type
3. Accept license terms
4. Complete installation
5. Note the connection string

#### 3. Configure IIS

```powershell
# Create application pool
New-WebAppPool -Name "GeniessAppPool"

# Set .NET version
Set-ItemProperty IIS:\AppPools\GeniessAppPool managedRuntimeVersion v4.0

# Create website
New-Website -Name "Geniess" -Port 80 -PhysicalPath "C:\inetpub\Geniess" -ApplicationPool "GeniessAppPool"
```

#### 4. Deploy Geniess Application

1. **Copy application files** to `C:\inetpub\Geniess`
2. **Configure database connection** in `web.config`:

```xml
<configuration>
  <connectionStrings>
    <add name="GeniessDB" 
         connectionString="Server=localhost;Database=Geniess;Integrated Security=true;" 
         providerName="System.Data.SqlClient" />
  </connectionStrings>
</configuration>
```

3. **Set folder permissions**:
```powershell
icacls "C:\inetpub\Geniess" /grant "IIS AppPool\GeniessAppPool:(OI)(CI)F" /T
```

4. **Restart IIS**:
```powershell
iisreset
```

### Configuration

#### Database Setup

Run database initialization scripts:

```sql
-- Create database
CREATE DATABASE Geniess;
GO

USE Geniess;
GO

-- Create tables (example)
CREATE TABLE Users (
    UserId INT PRIMARY KEY IDENTITY(1,1),
    Username NVARCHAR(100) NOT NULL,
    Email NVARCHAR(255) NOT NULL,
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO
```

#### Application Settings

Edit `appsettings.json`:

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=Geniess;Trusted_Connection=True;"
  },
  "ApiEndpoints": {
    "DruidBroker": "http://druid.horizen-network.com:8082"
  }
}
```

#### SSL Configuration (Optional)

1. Obtain SSL certificate for Windows
2. Import certificate to IIS:

```powershell
# Import certificate
Import-PfxCertificate -FilePath "C:\path\to\cert.pfx" -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString -String "password" -Force -AsPlainText)

# Bind to IIS
New-WebBinding -Name "Geniess" -Protocol https -Port 443
```

### Integration with Horizen Network

#### Configure Reverse Proxy

On the Linux server, update `nginx/conf.d/default.conf`:

```nginx
# Geniess subdomain
server {
    listen 80;
    server_name geniess.horizen-network.com;

    location / {
        proxy_pass http://WINDOWS_SERVER_IP:80;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Replace `WINDOWS_SERVER_IP` with your Windows server's IP address.

#### Configure Firewall

On Windows Server:

```powershell
# Allow HTTP
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Allow HTTPS
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
```

### Testing Geniess

1. Access via browser: `http://geniess.horizen-network.com`
2. Verify database connection
3. Test API endpoints
4. Check logs in IIS

## Integration

### Connecting Geniess to Druid

#### 1. Configure API Endpoint

In Geniess application:

```csharp
// Example C# code
public class DruidService
{
    private readonly string _druidBrokerUrl = "http://druid.horizen-network.com:8082";
    
    public async Task<string> ExecuteQuery(string query)
    {
        using (var client = new HttpClient())
        {
            var content = new StringContent(
                JsonConvert.SerializeObject(new { query = query }),
                Encoding.UTF8,
                "application/json"
            );
            
            var response = await client.PostAsync(
                $"{_druidBrokerUrl}/druid/v2/sql",
                content
            );
            
            return await response.Content.ReadAsStringAsync();
        }
    }
}
```

#### 2. Test Connection

```bash
# From Windows Server, test connectivity
curl http://druid.horizen-network.com:8082/status
```

### Data Flow

```
┌─────────────────┐
│   Data Sources  │
│ (Files, APIs,   │
│  Databases)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│     Geniess     │
│  (Processing &  │
│   Enrichment)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Apache Druid   │
│  (Analytics &   │
│    Storage)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Dashboards &  │
│   Visualization │
└─────────────────┘
```

## Configuration

### Performance Tuning

#### Druid Performance

```properties
# Increase query parallelism
druid.processing.numThreads=8
druid.processing.numMergeBuffers=4

# Increase cache size
druid.cache.sizeInBytes=1073741824

# Enable query result caching
druid.broker.cache.useCache=true
druid.broker.cache.populateCache=true
```

#### Geniess Performance

```xml
<!-- web.config -->
<system.web>
  <httpRuntime targetFramework="4.8" maxRequestLength="102400" />
  <compilation debug="false" targetFramework="4.8" />
</system.web>

<system.webServer>
  <httpCompression>
    <dynamicTypes>
      <add mimeType="application/json" enabled="true" />
    </dynamicTypes>
  </httpCompression>
</system.webServer>
```

### Security Configuration

#### Druid Security

Enable authentication in `common.runtime.properties`:

```properties
druid.auth.authenticatorChain=["basic"]
druid.auth.authenticator.basic.type=basic
druid.auth.authenticator.basic.initialAdminPassword=admin
druid.auth.authenticator.basic.initialInternalClientPassword=internal

druid.auth.authorizers=["basic"]
druid.auth.authorizer.basic.type=basic
```

#### Geniess Security

Enable authentication in `web.config`:

```xml
<system.web>
  <authentication mode="Forms">
    <forms loginUrl="~/Account/Login" timeout="2880" />
  </authentication>
  <authorization>
    <deny users="?" />
  </authorization>
</system.web>
```

## Troubleshooting

### Druid Issues

#### High Memory Usage

```bash
# Reduce heap size
DRUID_HEAP_SIZE=4g

# Reduce processing threads
druid.processing.numThreads=2

# Clear segment cache
docker-compose exec druid-historical rm -rf /opt/druid/var/druid/segment-cache/*
docker-compose restart druid-historical
```

#### Slow Queries

```sql
-- Check datasource size
SELECT datasource, COUNT(*) as segments
FROM sys.segments
GROUP BY datasource;

-- Check query performance
SELECT *
FROM sys.queries
ORDER BY duration DESC
LIMIT 10;
```

#### Ingestion Failures

```bash
# Check MiddleManager logs
docker-compose logs druid-middlemanager

# Check task status
curl http://localhost:8081/druid/indexer/v1/tasks
```

### Geniess Issues

#### Application Won't Start

```powershell
# Check IIS logs
Get-Content "C:\inetpub\logs\LogFiles\W3SVC1\*.log" -Tail 50

# Check Event Viewer
Get-EventLog -LogName Application -Source "ASP.NET*" -Newest 20
```

#### Database Connection Errors

```powershell
# Test SQL connection
Test-NetConnection -ComputerName localhost -Port 1433

# Check SQL Server service
Get-Service MSSQL*
```

#### Performance Issues

```powershell
# Check IIS worker process
Get-Process w3wp | Select-Object CPU, WorkingSet

# Recycle application pool
Restart-WebAppPool -Name "GeniessAppPool"
```

## Support

For application-specific issues:

- **Druid**: https://druid.apache.org/docs/latest/
- **Geniess**: Contact your vendor or check documentation
- **General**: Create an issue on GitHub

## Next Steps

1. Configure data sources in Druid
2. Setup Geniess data processing pipelines
3. Create dashboards and visualizations
4. Setup monitoring and alerting
5. Configure automated data ingestion
6. Implement data retention policies

---

**Note**: This guide provides general setup instructions. Actual Geniess configuration may vary based on your specific version and requirements. Consult your Geniess documentation for detailed instructions.
