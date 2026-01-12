"""
Horizen Network API Backend
FastAPI application with CORS support for handling API requests
"""

import logging
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
import os
from datetime import datetime, timezone
import uvicorn
from starlette.exceptions import HTTPException as StarletteHTTPException

# Configure logging
logging.basicConfig(level=logging.INFO)

# Initialize FastAPI app
app = FastAPI(
    title="Horizen Network API",
    description="API backend for Horizen Network - Advanced Data Analytics and Intelligence Platform",
    version="1.0.0",
)

# Configure CORS
# NOTE: For production deployment, consider:
# 1. Restricting localhost to specific ports (e.g., "http://localhost:8000")
# 2. Limiting allowed methods to only what's needed (e.g., ["GET", "POST"])
# 3. Restricting headers to specific ones required by your application
# 4. Setting allow_credentials=False if not needed
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
        timestamp=datetime.now(timezone.utc).isoformat(),
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
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        elif request.source_type == "url":
            # URL extraction (placeholder - requires additional libraries)
            # To implement full URL extraction, add to requirements.txt:
            # - beautifulsoup4>=4.12.0
            # - html2text>=2020.1.16
            # Then implement web scraping logic here
            extracted_text = f"Text extraction from URL: {request.source}"
            metadata = {
                "source_type": "url",
                "source_url": request.source,
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "note": "This is a placeholder. Full implementation requires web scraping libraries (beautifulsoup4, html2text)"
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
        # Log the error for debugging but don't expose details to client
        logging.error(f"Error during text extraction: {str(e)}")
        
        return TextExtractionResponse(
            success=False,
            error="An error occurred during text extraction",
            metadata={"timestamp": datetime.now(timezone.utc).isoformat()}
        )


# Error handlers
@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    """Handle HTTP exceptions"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail if hasattr(exc, 'detail') else "An error occurred",
            "status_code": exc.status_code
        }
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle general exceptions"""
    # Log the error for debugging
    logging.error(f"Unhandled exception: {str(exc)}", exc_info=True)
    
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal Server Error",
            "message": "An unexpected error occurred"
        }
    )


if __name__ == "__main__":
    # Run the application
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")
    
    uvicorn.run(
        app,
        host=host,
        port=port,
        log_level="info"
    )
