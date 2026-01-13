"""
Auth-Billing Service - Handles authentication, authorization, and billing integration.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional, List
import os

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext
from jose import JWTError, jwt
import uvicorn

# Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "changeme_jwt_secret_key_please")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))  # 24 hours
STRIPE_API_KEY = os.getenv("STRIPE_API_KEY", "")
STRIPE_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Security
security = HTTPBearer()

# FastAPI app
app = FastAPI(
    title="Horizen Auth-Billing Service",
    description="Authentication, authorization, and billing service",
    version="1.0.0",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory storage (DEVELOPMENT ONLY - Replace with persistent database in production)
# TODO: Replace with PostgreSQL or MongoDB for production deployment
# These dictionaries should be replaced with proper database models and queries
users_db = {}
user_entitlements_db = {}

# Entitlement types
class EntitlementType:
    BUNDLE_DRUID_GENIESS = "BUNDLE_DRUID_GENIESS"
    ENTITY = "ENTITY"

# Models
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class User(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    entitlements: List[str] = []
    created_at: datetime

class EntitlementCheck(BaseModel):
    has_access: bool
    entitlements: List[str]
    message: str

class StripeWebhook(BaseModel):
    type: str
    data: dict

# Helper functions
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> dict:
    """Decode and verify a JWT token."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """Get the current authenticated user from the JWT token."""
    token = credentials.credentials
    payload = decode_token(token)
    email = payload.get("sub")
    if email is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        )
    if email not in users_db:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return users_db[email]

# Routes
@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "service": "Horizen Auth-Billing Service",
        "version": "1.0.0",
        "status": "running",
    }

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}

@app.post("/api/auth/register", response_model=Token, status_code=status.HTTP_201_CREATED)
async def register(user: UserCreate):
    """Register a new user."""
    if user.email in users_db:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )
    
    # Hash password
    hashed_password = get_password_hash(user.password)
    
    # Store user
    users_db[user.email] = {
        "email": user.email,
        "hashed_password": hashed_password,
        "full_name": user.full_name,
        "created_at": datetime.now(timezone.utc),
    }
    
    # Initialize empty entitlements
    user_entitlements_db[user.email] = []
    
    # Create access token
    access_token = create_access_token(data={"sub": user.email})
    
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/auth/login", response_model=Token)
async def login(credentials: UserLogin):
    """Login a user."""
    if credentials.email not in users_db:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    user = users_db[credentials.email]
    if not verify_password(credentials.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    
    # Create access token
    access_token = create_access_token(data={"sub": credentials.email})
    
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/api/auth/me", response_model=User)
async def get_me(current_user: dict = Depends(get_current_user)):
    """Get current user information."""
    return {
        "email": current_user["email"],
        "full_name": current_user.get("full_name"),
        "entitlements": user_entitlements_db.get(current_user["email"], []),
        "created_at": current_user["created_at"],
    }

@app.post("/api/auth/verify", response_model=EntitlementCheck)
async def verify_token_and_entitlement(
    entitlement: Optional[str] = None,
    current_user: dict = Depends(get_current_user)
):
    """Verify JWT token and check if user has required entitlement."""
    user_entitlements = user_entitlements_db.get(current_user["email"], [])
    
    if entitlement:
        has_access = entitlement in user_entitlements
        message = f"Access {'granted' if has_access else 'denied'} for {entitlement}"
    else:
        has_access = True
        message = "Token valid"
    
    return {
        "has_access": has_access,
        "entitlements": user_entitlements,
        "message": message,
    }

@app.post("/api/entitlements/grant")
async def grant_entitlement(
    email: EmailStr,
    entitlement: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Grant an entitlement to a user (admin function).
    
    PRODUCTION NOTE: This endpoint should be protected with admin role verification.
    Currently simplified for v1 - any authenticated user can grant entitlements.
    TODO: Implement proper role-based access control (RBAC) before production deployment.
    """
    if email not in users_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    
    if email not in user_entitlements_db:
        user_entitlements_db[email] = []
    
    if entitlement not in user_entitlements_db[email]:
        user_entitlements_db[email].append(entitlement)
    
    return {
        "message": f"Entitlement {entitlement} granted to {email}",
        "entitlements": user_entitlements_db[email],
    }

@app.post("/api/billing/webhook")
async def stripe_webhook(webhook: dict):
    """
    Stripe webhook endpoint (phase 1 scaffolding).
    
    SECURITY WARNING: This endpoint currently lacks signature verification.
    Before production deployment, implement the following:
    
    1. Verify webhook signature using STRIPE_WEBHOOK_SECRET:
       ```python
       import stripe
       sig_header = request.headers.get('Stripe-Signature')
       event = stripe.Webhook.construct_event(
           payload, sig_header, STRIPE_WEBHOOK_SECRET
       )
       ```
    
    2. Handle specific event types:
       - checkout.session.completed: Grant entitlements
       - customer.subscription.deleted: Revoke entitlements
       - invoice.payment_failed: Handle failed payments
    
    3. Map Stripe product IDs to entitlements
    4. Implement idempotency to prevent duplicate processing
    5. Add comprehensive logging for audit trail
    
    TODO: Complete implementation before enabling payments
    """
    # TODO: Verify webhook signature using STRIPE_WEBHOOK_SECRET
    # For now, this is a placeholder
    
    event_type = webhook.get("type", "")
    
    if event_type == "checkout.session.completed":
        # Extract customer email and purchased product
        session = webhook.get("data", {}).get("object", {})
        customer_email = session.get("customer_email")
        
        # Placeholder: Grant entitlements based on product
        # In production, check the product ID and grant appropriate entitlements
        if customer_email and customer_email in users_db:
            # Example: Grant BUNDLE_DRUID_GENIESS for $5/mo product
            if customer_email not in user_entitlements_db:
                user_entitlements_db[customer_email] = []
            # This is placeholder logic - actual product mapping needed
            pass
    
    return {"status": "received"}

@app.get("/api/pricing")
async def get_pricing():
    """Get pricing information."""
    return {
        "bundles": [
            {
                "name": "Druid + Geniess Bundle",
                "price": 5.00,
                "currency": "USD",
                "interval": "month",
                "entitlement": EntitlementType.BUNDLE_DRUID_GENIESS,
                "description": "Access to Apache Druid analytics and Geniess AI platform",
            },
            {
                "name": "Entity Service",
                "price": 10.00,
                "currency": "USD",
                "interval": "month",
                "entitlement": EntitlementType.ENTITY,
                "description": "Access to Entity unified AI application",
            },
        ]
    }

if __name__ == "__main__":
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
