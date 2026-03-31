# Horizen Network - Authentication & Billing Guide

## Overview

The Horizen Network uses a **one-login architecture** where a single user account provides access to multiple services based on purchased entitlements.

## Architecture

```
┌──────────────────────────────────────────┐
│         User Authentication              │
│      (JWT-based, BCrypt hashing)         │
└──────────────┬───────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────┐
│      Entitlement Management              │
│  - BUNDLE_DRUID_GENIESS ($5/mo)         │
│  - ENTITY ($10/mo)                       │
└──────────────┬───────────────────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
   ┌─────────┐   ┌─────────┐
   │ Geniess │   │ Entity  │
   │  :8001  │   │  :8002  │
   └─────────┘   └─────────┘
```

## Services

### Auth-Billing Service (Port 8000)
- User registration and authentication
- JWT token generation and validation
- Entitlement management
- Stripe webhook integration (phase 1 scaffolding)

### Geniess Service (Port 8001)
- **Required Entitlement**: `BUNDLE_DRUID_GENIESS`
- AI-powered analytics platform
- Machine learning models
- Druid integration

### Entity Service (Port 8002)
- **Required Entitlement**: `ENTITY`
- Unified AI application platform
- Entity management
- Multi-model orchestration

## Pricing Model

| Bundle | Price | Services | Entitlement |
|--------|-------|----------|-------------|
| Druid + Geniess | $5/month | Apache Druid + Geniess AI | `BUNDLE_DRUID_GENIESS` |
| Entity Service | $10/month | Entity Unified AI | `ENTITY` |

## API Endpoints

### Authentication

#### Register a new user
```bash
POST /api/auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!",
  "full_name": "John Doe"
}

Response:
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

#### Login
```bash
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "SecurePassword123!"
}

Response:
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

#### Get current user
```bash
GET /api/auth/me
Authorization: Bearer <token>

Response:
{
  "email": "user@example.com",
  "full_name": "John Doe",
  "entitlements": ["BUNDLE_DRUID_GENIESS", "ENTITY"],
  "created_at": "2026-01-12T12:00:00"
}
```

#### Verify token and entitlement
```bash
POST /api/auth/verify?entitlement=BUNDLE_DRUID_GENIESS
Authorization: Bearer <token>

Response:
{
  "has_access": true,
  "entitlements": ["BUNDLE_DRUID_GENIESS"],
  "message": "Access granted for BUNDLE_DRUID_GENIESS"
}
```

### Entitlements

#### Grant entitlement (Admin function)
```bash
POST /api/entitlements/grant?email=user@example.com&entitlement=BUNDLE_DRUID_GENIESS
Authorization: Bearer <admin_token>

Response:
{
  "message": "Entitlement BUNDLE_DRUID_GENIESS granted to user@example.com",
  "entitlements": ["BUNDLE_DRUID_GENIESS"]
}
```

### Pricing

#### Get pricing information
```bash
GET /api/pricing

Response:
{
  "bundles": [
    {
      "name": "Druid + Geniess Bundle",
      "price": 5.00,
      "currency": "USD",
      "interval": "month",
      "entitlement": "BUNDLE_DRUID_GENIESS",
      "description": "Access to Apache Druid analytics and Geniess AI platform"
    },
    {
      "name": "Entity Service",
      "price": 10.00,
      "currency": "USD",
      "interval": "month",
      "entitlement": "ENTITY",
      "description": "Access to Entity unified AI application"
    }
  ]
}
```

### Billing (Stripe Integration - Phase 1)

#### Webhook endpoint
```bash
POST /api/billing/webhook
Content-Type: application/json

Stripe webhook payload
(Signature verification required in production)
```

## Access Control Flow

1. **User registers** → Receives JWT token
2. **User purchases subscription** → Stripe webhook triggers entitlement grant
3. **User accesses service** → Service validates token with auth-billing
4. **Auth-billing checks entitlement** → Returns access decision
5. **Service grants/denies access** → Based on entitlement check

## Environment Variables

### Required for Auth-Billing

```env
# JWT Configuration
JWT_SECRET_KEY=<generate_with_openssl_rand_-hex_32>
ACCESS_TOKEN_EXPIRE_MINUTES=1440  # 24 hours

# Stripe Configuration
STRIPE_API_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
```

### Generate JWT Secret
```bash
openssl rand -hex 32
```

## Security Best Practices

1. **Always use HTTPS in production**
2. **Store secrets in environment variables**, never in code
3. **Rotate JWT secrets regularly**
4. **Use strong passwords** (minimum 8 characters, mixed case, numbers, symbols)
5. **Validate webhook signatures** from Stripe
6. **Implement rate limiting** on authentication endpoints
7. **Log authentication attempts** for security monitoring

## Testing

Run the test script to verify the setup:

```bash
# Start services
docker-compose up -d

# Wait for services to be ready
sleep 10

# Run tests
./scripts/test-auth.sh
```

## Stripe Integration (Phase 1)

The current implementation includes scaffolding for Stripe integration:

1. **Webhook endpoint**: `/api/billing/webhook`
2. **Environment variables**: `STRIPE_API_KEY`, `STRIPE_WEBHOOK_SECRET`
3. **Placeholder logic**: Ready to map product IDs to entitlements

### Next Steps for Production:

1. Create products in Stripe dashboard:
   - Product 1: "Druid + Geniess Bundle" → Price: $5/month
   - Product 2: "Entity Service" → Price: $10/month

2. Configure webhook in Stripe:
   - URL: `https://api.horizen-network.com/api/billing/webhook`
   - Events to listen: `checkout.session.completed`, `customer.subscription.deleted`

3. Update webhook handler to:
   - Verify signature using `STRIPE_WEBHOOK_SECRET`
   - Map product IDs to entitlements
   - Grant/revoke entitlements based on events

## Troubleshooting

### 401 Unauthorized
- Token expired or invalid
- Check token in Authorization header: `Bearer <token>`
- Verify JWT_SECRET_KEY is consistent across restarts

### 403 Forbidden
- User lacks required entitlement
- Check user's entitlements: `GET /api/auth/me`
- Grant entitlement: `POST /api/entitlements/grant`

### 503 Service Unavailable
- Auth-billing service is down or unreachable
- Check service health: `curl http://auth-billing:8000/health`
- Verify Docker networking

## Support

For issues or questions:
- Email: admin@horizen-network.com
- Documentation: See README.md and docs/
