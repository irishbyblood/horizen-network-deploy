# Horizen Network API Documentation

## Overview

The Horizen Network API is a FastAPI-based backend service that provides CORS-enabled endpoints for health monitoring, text extraction, and other data processing tasks.

## Base URL

- **Development**: `http://localhost:8000`
- **Production**: `http://horizen-network.com` or your configured domain

## Getting Started

### Prerequisites

- Python 3.8 or higher
- pip (Python package installer)

### Installation

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:
```bash
python main.py
```

The API will start on `http://0.0.0.0:8000` by default.

### Configuration

Environment variables can be used to configure the application:

- `PORT`: Server port (default: 8000)
- `HOST`: Server host (default: 0.0.0.0)
- `ENVIRONMENT`: Environment name (default: production)

Example:
```bash
export PORT=8080
export ENVIRONMENT=development
python main.py
```

## CORS Configuration

The API is configured to accept requests from the following origins:

- `http://localhost` (all ports)
- `http://horizen-network.com`
- `https://horizen-network.com`
- All configured subdomains (www, druid, geniess, entity, api)

### Security Considerations

For production deployments, consider:

1. **Restrict localhost origins** to specific ports
2. **Limit HTTP methods** to only what's needed (GET, POST)
3. **Restrict headers** to specific ones required by your application
4. **Disable credentials** if not needed (`allow_credentials=False`)

## API Endpoints

### 1. Root Endpoint

**GET /** 

Returns API information and available endpoints.

**Response:**
```json
{
  "message": "Welcome to Horizen Network API",
  "version": "1.0.0",
  "documentation": "/docs",
  "health": "/health",
  "endpoints": {
    "health": "/health",
    "api": "/api",
    "extract": "/api/extract"
  }
}
```

### 2. Health Check

**GET /health**

Returns the health status of the API service.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-12T23:00:00.000000+00:00",
  "version": "1.0.0",
  "environment": "production"
}
```

**Status Codes:**
- `200 OK`: Service is healthy

### 3. API Root

**GET /api**

Returns information about available API endpoints.

**Response:**
```json
{
  "message": "Horizen Network API v1.0.0",
  "endpoints": {
    "extract": "/api/extract - Extract text from various sources",
    "health": "/health - Health check"
  }
}
```

### 4. Text Extraction

**POST /api/extract**

Extracts text from various sources.

**Request Body:**
```json
{
  "source": "Your text content or URL",
  "source_type": "text",
  "options": {}
}
```

**Parameters:**
- `source` (string, required): The text content or URL to extract from
- `source_type` (string, optional): Type of source
  - `"text"`: Direct text input (default)
  - `"url"`: URL to extract from (placeholder implementation)
- `options` (object, optional): Additional options for extraction

**Response (Success):**
```json
{
  "success": true,
  "extracted_text": "Your text content",
  "metadata": {
    "source_type": "text",
    "length": 20,
    "timestamp": "2026-01-12T23:00:00.000000+00:00"
  },
  "error": null
}
```

**Response (Error):**
```json
{
  "success": false,
  "extracted_text": null,
  "metadata": {
    "timestamp": "2026-01-12T23:00:00.000000+00:00"
  },
  "error": "An error occurred during text extraction"
}
```

**Status Codes:**
- `200 OK`: Text extraction successful
- `400 Bad Request`: Invalid source_type or request parameters
- `500 Internal Server Error`: Server error during processing

**Example (cURL):**

Extract from text:
```bash
curl -X POST "http://localhost:8000/api/extract" \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost" \
  -d '{
    "source": "Hello, World!",
    "source_type": "text"
  }'
```

Extract from URL (placeholder):
```bash
curl -X POST "http://localhost:8000/api/extract" \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost" \
  -d '{
    "source": "https://example.com",
    "source_type": "url"
  }'
```

**Note on URL Extraction:**
The URL extraction feature is currently a placeholder. To implement full URL extraction functionality, add the following libraries to `requirements.txt`:
- `beautifulsoup4>=4.12.0`
- `html2text>=2020.1.16`

### 5. Interactive Documentation

**GET /docs**

Access the interactive API documentation powered by Swagger UI.

**GET /redoc**

Access the alternative API documentation powered by ReDoc.

## Error Handling

The API uses standard HTTP status codes and returns JSON error responses:

### 404 Not Found
```json
{
  "error": "Not Found",
  "status_code": 404
}
```

### 400 Bad Request
```json
{
  "error": "Unsupported source_type: invalid. Supported types: text, url",
  "status_code": 400
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred"
}
```

## CORS Headers

All responses include the following CORS headers when a valid Origin is provided:

```
Access-Control-Allow-Origin: <origin>
Access-Control-Allow-Credentials: true
Access-Control-Allow-Methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
Access-Control-Max-Age: 600
```

### Preflight Requests

The API handles OPTIONS preflight requests automatically:

```bash
curl -X OPTIONS "http://localhost:8000/health" \
  -H "Origin: http://localhost" \
  -H "Access-Control-Request-Method: GET"
```

## Security

### Authentication

Currently, the API does not require authentication. For production deployments, consider implementing:

- JWT (JSON Web Tokens) authentication
- API key authentication
- OAuth 2.0

Libraries are already included in requirements.txt for JWT support (`python-jose[cryptography]`).

### Rate Limiting

Rate limiting is currently handled at the nginx level. Refer to the nginx configuration for details.

### Error Information

The API is designed to prevent information leakage:
- Internal errors are logged but not exposed to clients
- Error messages are sanitized
- Stack traces are never sent in responses

## Testing

### Manual Testing

Test the health endpoint:
```bash
curl http://localhost:8000/health
```

Test CORS headers:
```bash
curl -v -H "Origin: http://localhost" http://localhost:8000/health
```

Test text extraction:
```bash
curl -X POST http://localhost:8000/api/extract \
  -H "Content-Type: application/json" \
  -d '{"source": "Test text", "source_type": "text"}'
```

### Automated Testing

The API can be tested using tools like:
- pytest with pytest-asyncio
- Postman
- Thunder Client (VS Code extension)

## Deployment

### Docker Integration

The API can be integrated into the existing Docker Compose setup by adding a service:

```yaml
api:
  build:
    context: .
    dockerfile: Dockerfile.api
  ports:
    - "8000:8000"
  environment:
    - ENVIRONMENT=production
    - PORT=8000
  volumes:
    - ./main.py:/app/main.py
    - ./requirements.txt:/app/requirements.txt
  restart: unless-stopped
```

### Nginx Reverse Proxy

Configure nginx to proxy API requests:

```nginx
location /api/ {
    proxy_pass http://api:8000/api/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # CORS is handled by the API itself
}
```

## Logging

The API uses Python's built-in logging module. Logs include:

- Request/response information (via uvicorn)
- Error details for debugging
- Exception stack traces (not sent to clients)

Configure log level via environment:
```python
logging.basicConfig(level=logging.DEBUG)  # For development
logging.basicConfig(level=logging.INFO)   # For production
```

## Monitoring

Monitor the API health using the `/health` endpoint:

```bash
# Simple health check
curl http://localhost:8000/health

# With monitoring tools (e.g., Nagios, Prometheus)
curl -f http://localhost:8000/health || exit 1
```

## Version History

### v1.0.0 (2026-01-12)
- Initial release
- Health check endpoint
- Text extraction endpoint (text source)
- URL extraction endpoint (placeholder)
- Comprehensive CORS support
- Error handling and logging
- Interactive API documentation

## Support

For issues and questions:
1. Check the [documentation](https://github.com/irishbyblood/horizen-network-deploy/tree/main/docs)
2. Review existing issues on GitHub
3. Create a new issue with detailed information

## License

See [LICENSE](../LICENSE) file for details.
