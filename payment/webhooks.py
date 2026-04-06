#!/usr/bin/env python3
"""
Horizen Network - Stripe Webhook Handler
Handles Stripe webhook events for subscription updates
"""

import os
import logging
import stripe
import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Flask, request, jsonify
from datetime import datetime
from typing import Dict, Any

from subscription_manager import SubscriptionManager

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize Stripe
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
WEBHOOK_SECRET = os.getenv('STRIPE_WEBHOOK_SECRET')

# Initialize subscription manager
subscription_manager = SubscriptionManager()


def verify_webhook_signature(payload: bytes, sig_header: str) -> stripe.Event:
    """
    Verify Stripe webhook signature
    
    Args:
        payload: Raw request body
        sig_header: Stripe signature header
    
    Returns:
        Stripe Event object
    
    Raises:
        ValueError: If signature verification fails
    """
    try:
        event = stripe.Webhook.construct_event(
            payload, sig_header, WEBHOOK_SECRET
        )
        return event
    except ValueError as e:
        logger.error(f"Invalid payload: {str(e)}")
        raise
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {str(e)}")
        raise


def handle_subscription_created(event: Dict[str, Any]) -> None:
    """Handle subscription.created event"""
    subscription = event['data']['object']
    logger.info(f"Subscription created: {subscription['id']}")
    
    # Subscription is created via API, so we don't need to do anything here
    # The subscription is already in our database


def handle_subscription_updated(event: Dict[str, Any]) -> None:
    """Handle subscription.updated event"""
    subscription = event['data']['object']
    
    logger.info(f"Subscription updated: {subscription['id']}")
    
    # Update subscription status
    subscription_manager.update_subscription_status(
        stripe_subscription_id=subscription['id'],
        status=subscription['status'],
        period_end=datetime.fromtimestamp(subscription['current_period_end'])
    )


def handle_subscription_deleted(event: Dict[str, Any]) -> None:
    """Handle subscription.deleted event"""
    subscription = event['data']['object']
    
    logger.info(f"Subscription deleted: {subscription['id']}")
    
    # Update subscription status to canceled
    subscription_manager.update_subscription_status(
        stripe_subscription_id=subscription['id'],
        status='canceled'
    )


def handle_invoice_paid(event: Dict[str, Any]) -> None:
    """Handle invoice.paid event"""
    invoice = event['data']['object']
    
    logger.info(f"Invoice paid: {invoice['id']}")
    
    # Get subscription from invoice
    if invoice.get('subscription'):
        subscription_id = invoice['subscription']
        payment_intent_id = invoice.get('payment_intent', '')
        amount_paid = invoice['amount_paid']
        
        # Record successful payment
        try:
            # Get our subscription ID from Stripe subscription ID
            with subscription_manager._get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id FROM subscriptions
                        WHERE stripe_subscription_id = %s
                    """, (subscription_id,))
                    
                    result = cur.fetchone()
                    if result:
                        subscription_manager.record_payment(
                            subscription_id=result['id'],
                            stripe_payment_intent_id=payment_intent_id,
                            amount=amount_paid,
                            status='succeeded'
                        )
        except Exception as e:
            logger.error(f"Failed to record payment: {str(e)}")


def handle_invoice_payment_failed(event: Dict[str, Any]) -> None:
    """Handle invoice.payment_failed event"""
    invoice = event['data']['object']
    
    logger.warning(f"Invoice payment failed: {invoice['id']}")
    
    # Get subscription from invoice
    if invoice.get('subscription'):
        subscription_id = invoice['subscription']
        payment_intent_id = invoice.get('payment_intent', '')
        amount_due = invoice['amount_due']
        
        # Record failed payment
        try:
            with subscription_manager._get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id FROM subscriptions
                        WHERE stripe_subscription_id = %s
                    """, (subscription_id,))
                    
                    result = cur.fetchone()
                    if result:
                        subscription_manager.record_payment(
                            subscription_id=result['id'],
                            stripe_payment_intent_id=payment_intent_id,
                            amount=amount_due,
                            status='failed'
                        )
                        
                        # Update subscription status to past_due
                        subscription_manager.update_subscription_status(
                            stripe_subscription_id=subscription_id,
                            status='past_due'
                        )
        except Exception as e:
            logger.error(f"Failed to record failed payment: {str(e)}")


def handle_customer_subscription_trial_will_end(event: Dict[str, Any]) -> None:
    """Handle customer.subscription.trial_will_end event"""
    subscription = event['data']['object']
    
    logger.info(f"Trial ending soon for subscription: {subscription['id']}")
    
    # Here you could send an email notification to the customer
    # reminding them that their trial is ending soon


def handle_payment_intent_succeeded(event: Dict[str, Any]) -> None:
    """Handle payment_intent.succeeded event"""
    payment_intent = event['data']['object']
    
    logger.info(f"Payment succeeded: {payment_intent['id']}")


def handle_payment_intent_payment_failed(event: Dict[str, Any]) -> None:
    """Handle payment_intent.payment_failed event"""
    payment_intent = event['data']['object']
    
    logger.warning(f"Payment failed: {payment_intent['id']}")


# Event handler mapping
EVENT_HANDLERS = {
    'customer.subscription.created': handle_subscription_created,
    'customer.subscription.updated': handle_subscription_updated,
    'customer.subscription.deleted': handle_subscription_deleted,
    'invoice.paid': handle_invoice_paid,
    'invoice.payment_failed': handle_invoice_payment_failed,
    'customer.subscription.trial_will_end': handle_customer_subscription_trial_will_end,
    'payment_intent.succeeded': handle_payment_intent_succeeded,
    'payment_intent.payment_failed': handle_payment_intent_payment_failed
}


@app.route('/webhook', methods=['POST'])
def webhook():
    """
    Stripe webhook endpoint
    
    This endpoint receives events from Stripe and processes them accordingly
    """
    payload = request.data
    sig_header = request.headers.get('Stripe-Signature')
    
    if not sig_header:
        logger.error("Missing Stripe signature header")
        return jsonify({'error': 'Missing signature'}), 400
    
    try:
        # Verify webhook signature
        event = verify_webhook_signature(payload, sig_header)
        
        logger.info(f"Received webhook event: {event['type']}")
        
        # Handle the event
        event_type = event['type']
        handler = EVENT_HANDLERS.get(event_type)
        
        if handler:
            handler(event)
            logger.info(f"Successfully handled event: {event_type}")
        else:
            logger.warning(f"Unhandled event type: {event_type}")
        
        return jsonify({'status': 'success'}), 200
    
    except ValueError as e:
        logger.error(f"Invalid payload: {str(e)}")
        return jsonify({'error': 'Invalid payload'}), 400
    
    except stripe.error.SignatureVerificationError as e:
        logger.error(f"Invalid signature: {str(e)}")
        return jsonify({'error': 'Invalid signature'}), 400
    
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}", exc_info=True)
        return jsonify({'error': 'Internal server error'}), 500


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'payment-webhooks',
        'timestamp': datetime.now().isoformat()
    }), 200


@app.route('/', methods=['GET'])
def index():
    """Root endpoint"""
    return jsonify({
        'service': 'Horizen Network Payment Webhooks',
        'version': '1.0.0',
        'endpoints': {
            '/webhook': 'POST - Stripe webhook handler',
            '/health': 'GET - Health check'
        }
    }), 200


if __name__ == '__main__':
    # Check required environment variables
    required_vars = ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'POSTGRES_PASSWORD']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
        exit(1)
    
    # Get configuration from environment
    host = os.getenv('WEBHOOK_HOST', '0.0.0.0')
    port = int(os.getenv('WEBHOOK_PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    
    logger.info(f"Starting webhook server on {host}:{port}")
    app.run(host=host, port=port, debug=debug)
