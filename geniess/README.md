# Geniess Service

AI-powered analytics platform for Horizen Network.

## Features

- AI-powered data analysis
- Machine learning models
- Real-time intelligence
- Integration with Apache Druid
- Entitlement-based access control

## Access Requirements

Requires **BUNDLE_DRUID_GENIESS** entitlement ($5/month).

## Environment Variables

- `AUTH_BILLING_URL`: URL of the auth-billing service (default: http://auth-billing:8000)
- `PORT`: Server port (default: 8001)

## API Endpoints

All endpoints require a valid JWT token in the Authorization header and the BUNDLE_DRUID_GENIESS entitlement.

### GET /
Returns the Geniess web UI

### GET /health
Health check endpoint (no authentication required)

### GET /api/info
Get service information

Response:
```json
{
  "service": "Geniess AI Platform",
  "version": "1.0.0",
  "status": "operational",
  "features": ["AI-powered analytics", "Machine learning models", ...],
  "user_entitlements": ["BUNDLE_DRUID_GENIESS"]
}
```

### GET /api/models
List available AI models

### POST /api/analyze
Analyze data using Geniess AI

## Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally (requires auth-billing service running)
export AUTH_BILLING_URL=http://localhost:8000
python main.py
```

## Docker

```bash
# Build
docker build -t horizen-geniess .

# Run
docker run -p 8001:8001 \
  -e AUTH_BILLING_URL=http://auth-billing:8000 \
  horizen-geniess
```

## Testing

```bash
# Health check (no auth required)
curl http://localhost:8001/health

# Get info (requires token with BUNDLE_DRUID_GENIESS entitlement)
curl http://localhost:8001/api/info \
  -H "Authorization: Bearer <your_jwt_token>"
```

## Production Considerations

- Implement actual AI models and analytics capabilities
- Add persistent storage for model results
- Implement caching layer for frequently accessed data
- Add comprehensive error handling and logging
- Implement request rate limiting
- Add metrics and monitoring
