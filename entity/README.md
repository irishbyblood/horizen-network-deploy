# Entity Service

Unified AI application platform for Horizen Network.

## Features

- Unified AI application framework
- Advanced entity management
- Multi-model AI orchestration
- Enterprise-grade capabilities
- Entitlement-based access control

## Access Requirements

Requires **ENTITY** entitlement ($10/month).

## Environment Variables

- `AUTH_BILLING_URL`: URL of the auth-billing service (default: http://auth-billing:8000)
- `PORT`: Server port (default: 8002)

## API Endpoints

All endpoints require a valid JWT token in the Authorization header and the ENTITY entitlement.

### GET /
Returns the Entity web UI

### GET /health
Health check endpoint (no authentication required)

### GET /api/info
Get service information

Response:
```json
{
  "service": "Entity Unified AI Platform",
  "version": "1.0.0",
  "status": "operational",
  "features": ["Unified AI framework", "Entity management", ...],
  "user_entitlements": ["ENTITY"]
}
```

### GET /api/entities
List available entities

### POST /api/process
Process entity data

### GET /api/orchestration/status
Get orchestration system status

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
docker build -t horizen-entity .

# Run
docker run -p 8002:8002 \
  -e AUTH_BILLING_URL=http://auth-billing:8000 \
  horizen-entity
```

## Testing

```bash
# Health check (no auth required)
curl http://localhost:8002/health

# Get info (requires token with ENTITY entitlement)
curl http://localhost:8002/api/info \
  -H "Authorization: Bearer <your_jwt_token>"
```

## Production Considerations

- Implement actual entity management capabilities
- Add persistent storage for entities and processing results
- Implement orchestration engine for complex workflows
- Add comprehensive error handling and logging
- Implement request rate limiting
- Add metrics and monitoring
- Implement entity versioning and history
