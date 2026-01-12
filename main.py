"""
Horizen Network API Backend
FastAPI application with CORS support for handling API requests
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
import os
from datetime import datetime

# Initialize FastAPI app
app = FastAPI(
    title="Horizen Network API",
    description="API backend for Horizen Network - Advanced Data Analytics and Intelligence Platform",
    version="1.0.0",
)

# Configure CORS
# Allow all origins for development, restrict in production
origins = [
    "http://localhost",
    "http://localhost:80",
    "http://localhost:8000",
    "http://horizen-network.com",
    "https://horizen-network.com",
    "http://www.horizen-network.com",
    "https://www.horizen-network.com",
    "http://druid.horizen-network.com",
    "https://druid.horizen-network.com",
    "http://geniess.horizen-network.com",
    "https://geniess.horizen-network.com",
]

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,  # Allows specified origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods (GET, POST, PUT, DELETE, etc.)
    allow_headers=["*"],  # Allows all headers
)


# Pydantic models
class HealthResponse(BaseModel):
    """Health check response model"""
    status: str
    timestamp: str
    version: str
    environment: Optional[str] = "production"


class TextExtractionRequest(BaseModel):
    """Request model for text extraction"""
    source: str
    source_type: Optional[str] = "url"
    options: Optional[Dict[str, Any]] = {}


class TextExtractionResponse(BaseModel):
    """Response model for text extraction"""
    success: bool
    extracted_text: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = {}
    error: Optional[str] = None


# Root endpoint
@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Welcome to Horizen Network API",
        "version": "1.0.0",
        "documentation": "/docs",
        "health": "/health",
        "endpoints": {
            "health": "/health",
            "api": "/api",
            "extract": "/api/extract",
        }
    }


# Health check endpoint
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Health check endpoint to verify API is running
    Returns current status, timestamp, and version
    """
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow().isoformat(),
        version="1.0.0",
        environment=os.getenv("ENVIRONMENT", "production")
    )


# API root
@app.get("/api")
async def api_root():
    """API root endpoint"""
    return {
        "message": "Horizen Network API v1.0.0",
        "endpoints": {
            "extract": "/api/extract - Extract text from various sources",
            "health": "/health - Health check",
        }
    }


# Text extraction endpoint (placeholder)
@app.post("/api/extract", response_model=TextExtractionResponse)
async def extract_text(request: TextExtractionRequest):
    """
    Extract text from various sources
    
    Supports:
    - URLs (web pages)
    - Raw text
    - File content (future enhancement)
    
    Args:
        request: TextExtractionRequest containing source and options
        
    Returns:
        TextExtractionResponse with extracted text and metadata
    """
    try:
        # Basic text extraction implementation
        if request.source_type == "text":
            # Direct text input
            extracted_text = request.source
            metadata = {
                "source_type": "text",
                "length": len(extracted_text),
                "timestamp": datetime.utcnow().isoformat()
            }
        elif request.source_type == "url":
            # URL extraction (placeholder - would need requests/beautifulsoup in production)
            extracted_text = f"Text extraction from URL: {request.source}"
            metadata = {
                "source_type": "url",
                "source_url": request.source,
                "timestamp": datetime.utcnow().isoformat(),
                "note": "Full implementation requires web scraping libraries"
            }
        else:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported source_type: {request.source_type}. Supported types: text, url"
            )
        
        return TextExtractionResponse(
            success=True,
            extracted_text=extracted_text,
            metadata=metadata
        )
        
    except HTTPException:
        raise
    except Exception as e:
        return TextExtractionResponse(
            success=False,
            error=str(e),
            metadata={"timestamp": datetime.utcnow().isoformat()}
        )


# Error handlers
@app.exception_handler(404)
async def not_found_handler(request, exc):
    """Handle 404 errors"""
    return JSONResponse(
        status_code=404,
        content={
            "error": "Not Found",
            "message": "The requested resource was not found",
            "path": str(request.url)
        }
    )


@app.exception_handler(500)
async def internal_error_handler(request, exc):
    """Handle 500 errors"""
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An unexpected error occurred"
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    # Run the application
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info"
    )
