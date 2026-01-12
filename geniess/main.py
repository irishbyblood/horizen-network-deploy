"""
Geniess Service - AI platform with entitlement-based access control.
Requires BUNDLE_DRUID_GENIESS entitlement.
"""
import os
from typing import Optional

from fastapi import FastAPI, HTTPException, Depends, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
import httpx
import uvicorn

# Configuration
AUTH_BILLING_URL = os.getenv("AUTH_BILLING_URL", "http://auth-billing:8000")
# Fallback to localhost if auth-billing hostname doesn't resolve (for local testing)
if AUTH_BILLING_URL == "http://auth-billing:8000":
    try:
        import socket
        socket.gethostbyname("auth-billing")
    except socket.gaierror:
        AUTH_BILLING_URL = "http://localhost:8000"

REQUIRED_ENTITLEMENT = "BUNDLE_DRUID_GENIESS"

# Security
security = HTTPBearer()

# FastAPI app
app = FastAPI(
    title="Geniess Service",
    description="Geniess AI platform - requires BUNDLE_DRUID_GENIESS entitlement",
    version="1.0.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Entitlement validation
async def verify_entitlement(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Verify user has required entitlement by calling auth-billing service."""
    token = credentials.credentials
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                f"{AUTH_BILLING_URL}/api/auth/verify",
                params={"entitlement": REQUIRED_ENTITLEMENT},
                headers={"Authorization": f"Bearer {token}"},
                timeout=10.0,
            )
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid authentication credentials",
                )
            
            result = response.json()
            
            if not result.get("has_access"):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"Access denied. Required entitlement: {REQUIRED_ENTITLEMENT}",
                )
            
            return result
            
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Auth service unavailable",
            )

# Routes
@app.get("/", response_class=HTMLResponse)
async def root():
    """Root endpoint with simple UI."""
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Geniess - AI Platform</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background-color: #f5f5f5;
            }
            .container {
                background-color: white;
                padding: 30px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            h1 {
                color: #2c3e50;
            }
            .feature {
                margin: 20px 0;
                padding: 15px;
                background-color: #ecf0f1;
                border-radius: 5px;
            }
            .note {
                color: #7f8c8d;
                font-size: 14px;
                margin-top: 20px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🧠 Geniess AI Platform</h1>
            <p>Welcome to Geniess - Advanced AI-powered intelligence platform.</p>
            
            <div class="feature">
                <h3>Features:</h3>
                <ul>
                    <li>AI-powered data analysis</li>
                    <li>Machine learning models</li>
                    <li>Real-time intelligence</li>
                    <li>Integration with Apache Druid</li>
                </ul>
            </div>
            
            <div class="feature">
                <h3>Access Requirements:</h3>
                <p>This service requires the <strong>Druid + Geniess Bundle</strong> subscription ($5/month).</p>
                <p>Contact admin@horizen-network.com to upgrade your account.</p>
            </div>
            
            <div class="note">
                <p><strong>Note:</strong> This is a minimal v1 implementation. Full UI and features coming soon.</p>
            </div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "geniess"}

@app.get("/api/info")
async def get_info(entitlement_check: dict = Depends(verify_entitlement)):
    """Get service information (requires entitlement)."""
    return {
        "service": "Geniess AI Platform",
        "version": "1.0.0",
        "status": "operational",
        "features": [
            "AI-powered analytics",
            "Machine learning models",
            "Real-time intelligence",
            "Druid integration",
        ],
        "user_entitlements": entitlement_check.get("entitlements", []),
    }

@app.get("/api/models")
async def list_models(entitlement_check: dict = Depends(verify_entitlement)):
    """List available AI models (requires entitlement)."""
    return {
        "models": [
            {
                "id": "geniess-analytics-v1",
                "name": "Geniess Analytics Model",
                "type": "analytics",
                "status": "active",
            },
            {
                "id": "geniess-prediction-v1",
                "name": "Geniess Prediction Model",
                "type": "prediction",
                "status": "active",
            },
        ]
    }

@app.post("/api/analyze")
async def analyze_data(
    data: dict,
    entitlement_check: dict = Depends(verify_entitlement)
):
    """Analyze data using Geniess AI (requires entitlement)."""
    # Placeholder implementation
    return {
        "status": "success",
        "message": "Data analysis completed",
        "results": {
            "input_size": len(str(data)),
            "processing_time": "0.5s",
            "insights": "Placeholder insights - full implementation coming soon",
        }
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8001"))
    uvicorn.run(app, host="0.0.0.0", port=port)
