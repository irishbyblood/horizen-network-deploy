# Auth-Billing Service

Authentication and billing service for Horizen Network.

## Features

- User registration and login with email/password
- Secure password hashing using BCrypt
- JWT-based session management
- Entitlement-based access control
- Stripe integration scaffolding for payment processing

## Environment Variables

- `JWT_SECRET_KEY`: Secret key for signing JWT tokens (generate with `openssl rand -hex 32`)
- `ACCESS_TOKEN_EXPIRE_MINUTES`: JWT token expiration time in minutes (default: 1440 = 24 hours)
- `STRIPE_API_KEY`: Stripe secret API key
- `STRIPE_WEBHOOK_SECRET`: Stripe webhook signing secret
- `PORT`: Server port (default: 8000)

## API Endpoints

See [AUTHENTICATION.md](../docs/AUTHENTICATION.md) for complete API documentation.

## Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally
python main.py
```

## Docker

```bash
# Build
docker build -t horizen-auth-billing .

# Run
docker run -p 8000:8000 \
  -e JWT_SECRET_KEY=your_secret_key \
  -e STRIPE_API_KEY=your_stripe_key \
  horizen-auth-billing
```

## Testing

```bash
# Health check
curl http://localhost:8000/health

# Register user
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass"}'

# Login
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass"}'
```

## Production Considerations

- Use a real database (PostgreSQL/MongoDB) instead of in-memory storage
- Implement proper session management and token blacklisting
- Add rate limiting on authentication endpoints
- Implement password reset functionality
- Add email verification
- Complete Stripe integration with signature verification
- Add comprehensive logging and monitoring
- Implement admin endpoints for user management
