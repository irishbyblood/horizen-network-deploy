# Horizen Network Payment Service

This directory contains the payment integration for Horizen Network using Stripe.

## Overview

The payment service handles:
- Stripe payment processing
- Subscription management
- Webhook event handling
- Payment history tracking

## Components

### 1. stripe-integration.py
Core Stripe API integration handling:
- Customer management
- Subscription creation and updates
- Checkout session creation
- Billing portal access
- Invoice management

### 2. subscription-manager.py
Database-backed subscription lifecycle management:
- Subscription creation and storage
- Access control verification
- Payment history recording
- Subscription status synchronization

### 3. webhooks.py
Flask-based webhook server for processing Stripe events:
- Subscription updates
- Payment confirmations
- Invoice events
- Trial period notifications

## Subscription Plans

### Druid + Geniess Bundle
- **Price**: $15/month
- **Includes**: Access to Druid analytics and Geniess intelligence platform
- **Plan ID**: `price_druid_geniess_monthly`

### Entity AI
- **Price**: $5/month
- **Includes**: Access to Entity AI web application
- **Plan ID**: `price_entity_monthly`

## Setup

### 1. Install Dependencies

```bash
cd payment
pip install -r requirements.txt
```

### 2. Configure Environment Variables

Create a `.env` file or set the following environment variables:

```bash
# Stripe API Keys
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Product Price IDs (create these in Stripe Dashboard)
STRIPE_DRUID_GENIESS_PRICE_ID=price_druid_geniess_monthly
STRIPE_ENTITY_PRICE_ID=price_entity_monthly

# Database Configuration
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
POSTGRES_DB=horizen_network
POSTGRES_USER=druid
POSTGRES_PASSWORD=your_secure_password
```

### 3. Create Stripe Products and Prices

In the Stripe Dashboard:

1. Create a product "Druid + Geniess Bundle"
   - Set recurring price: $15/month
   - Copy the price ID to `STRIPE_DRUID_GENIESS_PRICE_ID`

2. Create a product "Entity AI"
   - Set recurring price: $5/month
   - Copy the price ID to `STRIPE_ENTITY_PRICE_ID`

### 4. Configure Webhook Endpoint

1. In Stripe Dashboard, go to Developers > Webhooks
2. Add endpoint: `https://horizen-network.com/api/payment/webhook`
3. Select events to listen for:
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.paid`
   - `invoice.payment_failed`
   - `customer.subscription.trial_will_end`
   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
4. Copy the signing secret to `STRIPE_WEBHOOK_SECRET`

## Deployment

### Using Docker Compose

```bash
# Deploy payment service
docker-compose -f docker-compose.payment.yml up -d

# View logs
docker-compose -f docker-compose.payment.yml logs -f

# Stop service
docker-compose -f docker-compose.payment.yml down
```

### Running Standalone

```bash
# Start webhook server
python webhooks.py
```

The webhook server will run on `http://0.0.0.0:5000`

## API Usage

### Python Example

```python
from stripe_integration import StripePaymentService
from subscription_manager import SubscriptionManager

# Initialize services
payment_service = StripePaymentService()
subscription_manager = SubscriptionManager()

# Create a subscription
result = subscription_manager.create_subscription(
    user_id=123,
    email="user@example.com",
    plan_type="druid_geniess",
    name="John Doe",
    trial_days=7  # Optional trial period
)

print(f"Subscription created: {result['subscription_id']}")
print(f"Client secret: {result['client_secret']}")

# Check subscription access
access = subscription_manager.check_subscription_access(
    user_id=123,
    required_plan="druid_geniess"
)

if access['has_access']:
    print("User has access!")
else:
    print(f"No access: {access['reason']}")

# Cancel subscription
cancellation = subscription_manager.cancel_subscription(
    user_id=123,
    immediate=False  # Cancel at period end
)
```

## Database Schema

The payment service uses the following tables:

### subscriptions
```sql
CREATE TABLE subscriptions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    stripe_customer_id VARCHAR(255) NOT NULL,
    stripe_subscription_id VARCHAR(255) NOT NULL,
    plan_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    current_period_end TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    canceled_at TIMESTAMP
);
```

### payment_history
```sql
CREATE TABLE payment_history (
    id SERIAL PRIMARY KEY,
    subscription_id INTEGER REFERENCES subscriptions(id),
    stripe_payment_intent_id VARCHAR(255),
    amount INTEGER NOT NULL,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

## Testing

### Test Stripe Integration

```bash
# Test with Stripe test keys
export STRIPE_SECRET_KEY=sk_test_...
python stripe-integration.py
```

### Test Subscription Manager

```bash
# Ensure database is running and configured
python subscription-manager.py
```

### Test Webhooks Locally

Use Stripe CLI to forward webhooks:

```bash
# Install Stripe CLI
# https://stripe.com/docs/stripe-cli

# Login to Stripe
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:5000/webhook

# Trigger test events
stripe trigger customer.subscription.created
stripe trigger invoice.paid
```

## Security Considerations

1. **Never commit API keys**: Use environment variables
2. **Verify webhook signatures**: Always verify Stripe signatures
3. **Use HTTPS in production**: Webhooks require HTTPS
4. **Secure database access**: Use strong passwords and limit access
5. **PCI Compliance**: Never store card data - let Stripe handle it
6. **Rate limiting**: Implement rate limiting on payment endpoints

## Monitoring

### Health Check

```bash
curl http://localhost:5000/health
```

### Logs

```bash
# Docker logs
docker-compose -f docker-compose.payment.yml logs -f payment-webhooks

# Application logs (if running standalone)
tail -f logs/payment.log
```

## Troubleshooting

### Webhook Not Receiving Events

1. Check webhook URL is accessible from internet
2. Verify webhook secret is correct
3. Check Stripe Dashboard > Webhooks for delivery attempts
4. Ensure firewall allows inbound traffic on webhook port

### Payment Failures

1. Check Stripe Dashboard for error details
2. Verify customer has valid payment method
3. Check for insufficient funds or card declines
4. Review payment history in database

### Database Connection Issues

1. Verify PostgreSQL is running
2. Check database credentials
3. Ensure database has required tables (run migrations)
4. Check network connectivity to database

## Support

For issues related to:
- **Stripe API**: https://stripe.com/docs
- **Payment service**: Create an issue on GitHub
- **Database setup**: See `migrations/` directory

## License

This project is released into the public domain under the Unlicense.
