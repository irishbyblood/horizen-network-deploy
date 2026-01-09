#!/usr/bin/env python3
"""
Horizen Network - Subscription Manager
Manages subscription lifecycle and database operations
"""

import os
import logging
from typing import Dict, Optional, List
from datetime import datetime, timedelta
from dataclasses import dataclass
import psycopg2
from psycopg2.extras import RealDictCursor
import stripe

from stripe_integration import StripePaymentService

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class Subscription:
    """Subscription data model"""
    id: int
    user_id: int
    stripe_customer_id: str
    stripe_subscription_id: str
    plan_type: str
    status: str
    current_period_end: datetime
    created_at: datetime
    cancel_at_period_end: bool = False
    canceled_at: Optional[datetime] = None


class SubscriptionManager:
    """Manages subscription lifecycle and database operations"""
    
    def __init__(self):
        """Initialize subscription manager with database and Stripe connections"""
        self.stripe_service = StripePaymentService()
        self.db_config = {
            'host': os.getenv('POSTGRES_HOST', 'postgres'),
            'port': int(os.getenv('POSTGRES_PORT', 5432)),
            'database': os.getenv('POSTGRES_DB', 'horizen_network'),
            'user': os.getenv('POSTGRES_USER', 'druid'),
            'password': os.getenv('POSTGRES_PASSWORD')
        }
        
        if not self.db_config['password']:
            raise ValueError("POSTGRES_PASSWORD environment variable not set")
        
        logger.info("Subscription Manager initialized")
    
    def _get_db_connection(self):
        """Get database connection"""
        return psycopg2.connect(**self.db_config)
    
    def create_subscription(self, user_id: int, email: str, plan_type: str,
                          name: Optional[str] = None, trial_days: Optional[int] = None) -> Dict:
        """
        Create a new subscription for a user
        
        Args:
            user_id: User ID from application
            email: User email address
            plan_type: Plan type ('druid_geniess' or 'entity')
            name: User name (optional)
            trial_days: Number of trial days (optional)
        
        Returns:
            Dictionary with subscription details and checkout URL
        """
        try:
            with self._get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    # Check if user already has an active subscription
                    cur.execute("""
                        SELECT id, stripe_subscription_id, plan_type, status
                        FROM subscriptions
                        WHERE user_id = %s AND status IN ('active', 'trialing')
                        LIMIT 1
                    """, (user_id,))
                    
                    existing = cur.fetchone()
                    if existing:
                        logger.warning(f"User {user_id} already has active subscription: {existing['id']}")
                        return {
                            'success': False,
                            'error': 'User already has an active subscription',
                            'existing_subscription': dict(existing)
                        }
                    
                    # Create or get Stripe customer
                    cur.execute("""
                        SELECT stripe_customer_id
                        FROM subscriptions
                        WHERE user_id = %s
                        ORDER BY created_at DESC
                        LIMIT 1
                    """, (user_id,))
                    
                    result = cur.fetchone()
                    if result and result['stripe_customer_id']:
                        customer_id = result['stripe_customer_id']
                        customer = self.stripe_service.get_customer(customer_id)
                    else:
                        customer = self.stripe_service.create_customer(
                            email=email,
                            name=name,
                            metadata={'user_id': user_id}
                        )
                        customer_id = customer.id
                    
                    # Create Stripe subscription
                    subscription = self.stripe_service.create_subscription(
                        customer_id=customer_id,
                        plan_type=plan_type,
                        trial_days=trial_days
                    )
                    
                    # Calculate period end
                    if subscription.trial_end:
                        period_end = datetime.fromtimestamp(subscription.trial_end)
                    else:
                        period_end = datetime.fromtimestamp(subscription.current_period_end)
                    
                    # Store in database
                    cur.execute("""
                        INSERT INTO subscriptions 
                        (user_id, stripe_customer_id, stripe_subscription_id, 
                         plan_type, status, current_period_end)
                        VALUES (%s, %s, %s, %s, %s, %s)
                        RETURNING id
                    """, (
                        user_id,
                        customer_id,
                        subscription.id,
                        plan_type,
                        subscription.status,
                        period_end
                    ))
                    
                    subscription_id = cur.fetchone()['id']
                    conn.commit()
                    
                    logger.info(f"Created subscription {subscription_id} for user {user_id}")
                    
                    return {
                        'success': True,
                        'subscription_id': subscription_id,
                        'stripe_subscription_id': subscription.id,
                        'status': subscription.status,
                        'client_secret': subscription.latest_invoice.payment_intent.client_secret if hasattr(subscription.latest_invoice, 'payment_intent') else None
                    }
        
        except Exception as e:
            logger.error(f"Failed to create subscription: {str(e)}")
            raise
    
    def get_subscription(self, user_id: int) -> Optional[Subscription]:
        """
        Get active subscription for a user
        
        Args:
            user_id: User ID
        
        Returns:
            Subscription object or None if not found
        """
        try:
            with self._get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT id, user_id, stripe_customer_id, stripe_subscription_id,
                               plan_type, status, current_period_end, created_at,
                               cancel_at_period_end, canceled_at
                        FROM subscriptions
                        WHERE user_id = %s
                        ORDER BY created_at DESC
                        LIMIT 1
                    """, (user_id,))
                    
                    row = cur.fetchone()
                    if row:
                        return Subscription(**row)
                    return None
        
        except Exception as e:
            logger.error(f"Failed to get subscription: {str(e)}")
            raise
    
    def check_subscription_access(self, user_id: int, required_plan: Optional[str] = None) -> Dict:
        """
        Check if user has access to services
        
        Args:
            user_id: User ID
            required_plan: Specific plan type required (optional)
        
        Returns:
            Dictionary with access status and details
        """
        try:
            subscription = self.get_subscription(user_id)
            
            if not subscription:
                return {
                    'has_access': False,
                    'reason': 'No subscription found',
                    'plan_type': None,
                    'status': None
                }
            
            # Check if subscription is active
            active_statuses = ['active', 'trialing']
            if subscription.status not in active_statuses:
                return {
                    'has_access': False,
                    'reason': f'Subscription is {subscription.status}',
                    'plan_type': subscription.plan_type,
                    'status': subscription.status
                }
            
            # Check if period has ended
            if subscription.current_period_end < datetime.now():
                return {
                    'has_access': False,
                    'reason': 'Subscription period has ended',
                    'plan_type': subscription.plan_type,
                    'status': subscription.status
                }
            
            # Check if specific plan is required
            if required_plan and subscription.plan_type != required_plan:
                # Allow druid_geniess subscribers to access entity
                if not (subscription.plan_type == 'druid_geniess' and required_plan == 'entity'):
                    return {
                        'has_access': False,
                        'reason': f'Plan {required_plan} required, user has {subscription.plan_type}',
                        'plan_type': subscription.plan_type,
                        'status': subscription.status
                    }
            
            return {
                'has_access': True,
                'plan_type': subscription.plan_type,
                'status': subscription.status,
                'period_end': subscription.current_period_end.isoformat(),
                'cancel_at_period_end': subscription.cancel_at_period_end
            }
        
        except Exception as e:
            logger.error(f"Failed to check subscription access: {str(e)}")
            return {
                'has_access': False,
                'reason': 'Error checking subscription',
                'error': str(e)
            }
    
    def cancel_subscription(self, user_id: int, immediate: bool = False) -> Dict:
        """
        Cancel a user's subscription
        
        Args:
            user_id: User ID
            immediate: Cancel immediately (True) or at period end (False)
        
        Returns:
            Dictionary with cancellation status
        """
        try:
            subscription = self.get_subscription(user_id)
            
            if not subscription:
                return {
                    'success': False,
                    'error': 'No subscription found'
                }
            
            if subscription.status not in ['active', 'trialing']:
                return {
                    'success': False,
                    'error': f'Cannot cancel subscription with status: {subscription.status}'
                }
            
            # Cancel in Stripe
            stripe_subscription = self.stripe_service.cancel_subscription(
                subscription.stripe_subscription_id,
                at_period_end=not immediate
            )
            
            # Update database
            with self._get_db_connection() as conn:
                with conn.cursor() as cur:
                    if immediate:
                        cur.execute("""
                            UPDATE subscriptions
                            SET status = 'canceled',
                                canceled_at = %s,
                                cancel_at_period_end = FALSE
                            WHERE id = %s
                        """, (datetime.now(), subscription.id))
                    else:
                        cur.execute("""
                            UPDATE subscriptions
                            SET cancel_at_period_end = TRUE,
                                canceled_at = %s
                            WHERE id = %s
                        """, (datetime.now(), subscription.id))
                    
                    conn.commit()
            
            logger.info(f"Cancelled subscription {subscription.id} for user {user_id}")
            
            return {
                'success': True,
                'immediate': immediate,
                'period_end': subscription.current_period_end.isoformat() if not immediate else None
            }
        
        except Exception as e:
            logger.error(f"Failed to cancel subscription: {str(e)}")
            raise
    
    def reactivate_subscription(self, user_id: int) -> Dict:
        """
        Reactivate a cancelled subscription (if not yet ended)
        
        Args:
            user_id: User ID
        
        Returns:
            Dictionary with reactivation status
        """
        try:
            subscription = self.get_subscription(user_id)
            
            if not subscription:
                return {
                    'success': False,
                    'error': 'No subscription found'
                }
            
            if not subscription.cancel_at_period_end:
                return {
                    'success': False,
                    'error': 'Subscription is not scheduled for cancellation'
                }
            
            # Reactivate in Stripe
            self.stripe_service.reactivate_subscription(subscription.stripe_subscription_id)
            
            # Update database
            with self._get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        UPDATE subscriptions
                        SET cancel_at_period_end = FALSE,
                            canceled_at = NULL
                        WHERE id = %s
                    """, (subscription.id,))
                    conn.commit()
            
            logger.info(f"Reactivated subscription {subscription.id} for user {user_id}")
            
            return {
                'success': True,
                'message': 'Subscription reactivated successfully'
            }
        
        except Exception as e:
            logger.error(f"Failed to reactivate subscription: {str(e)}")
            raise
    
    def update_subscription_status(self, stripe_subscription_id: str, 
                                  status: str, period_end: Optional[datetime] = None) -> None:
        """
        Update subscription status from webhook
        
        Args:
            stripe_subscription_id: Stripe subscription ID
            status: New status
            period_end: New period end date (optional)
        """
        try:
            with self._get_db_connection() as conn:
                with conn.cursor() as cur:
                    if period_end:
                        cur.execute("""
                            UPDATE subscriptions
                            SET status = %s, current_period_end = %s
                            WHERE stripe_subscription_id = %s
                        """, (status, period_end, stripe_subscription_id))
                    else:
                        cur.execute("""
                            UPDATE subscriptions
                            SET status = %s
                            WHERE stripe_subscription_id = %s
                        """, (status, stripe_subscription_id))
                    
                    conn.commit()
            
            logger.info(f"Updated subscription {stripe_subscription_id} status to {status}")
        
        except Exception as e:
            logger.error(f"Failed to update subscription status: {str(e)}")
            raise
    
    def record_payment(self, subscription_id: int, stripe_payment_intent_id: str,
                      amount: int, status: str) -> None:
        """
        Record a payment in the database
        
        Args:
            subscription_id: Subscription ID
            stripe_payment_intent_id: Stripe payment intent ID
            amount: Amount in cents
            status: Payment status
        """
        try:
            with self._get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        INSERT INTO payment_history
                        (subscription_id, stripe_payment_intent_id, amount, status)
                        VALUES (%s, %s, %s, %s)
                    """, (subscription_id, stripe_payment_intent_id, amount, status))
                    conn.commit()
            
            logger.info(f"Recorded payment for subscription {subscription_id}: {amount} cents")
        
        except Exception as e:
            logger.error(f"Failed to record payment: {str(e)}")
            raise
    
    def get_payment_history(self, user_id: int, limit: int = 10) -> List[Dict]:
        """
        Get payment history for a user
        
        Args:
            user_id: User ID
            limit: Maximum number of payments to return
        
        Returns:
            List of payment dictionaries
        """
        try:
            with self._get_db_connection() as conn:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    cur.execute("""
                        SELECT ph.id, ph.stripe_payment_intent_id, ph.amount,
                               ph.status, ph.created_at, s.plan_type
                        FROM payment_history ph
                        JOIN subscriptions s ON ph.subscription_id = s.id
                        WHERE s.user_id = %s
                        ORDER BY ph.created_at DESC
                        LIMIT %s
                    """, (user_id, limit))
                    
                    return [dict(row) for row in cur.fetchall()]
        
        except Exception as e:
            logger.error(f"Failed to get payment history: {str(e)}")
            raise
    
    def sync_subscription_with_stripe(self, user_id: int) -> Dict:
        """
        Sync local subscription with Stripe data
        
        Args:
            user_id: User ID
        
        Returns:
            Dictionary with sync status
        """
        try:
            subscription = self.get_subscription(user_id)
            
            if not subscription:
                return {
                    'success': False,
                    'error': 'No subscription found'
                }
            
            # Get latest from Stripe
            stripe_subscription = self.stripe_service.get_subscription(
                subscription.stripe_subscription_id
            )
            
            if not stripe_subscription:
                return {
                    'success': False,
                    'error': 'Subscription not found in Stripe'
                }
            
            # Update database
            with self._get_db_connection() as conn:
                with conn.cursor() as cur:
                    cur.execute("""
                        UPDATE subscriptions
                        SET status = %s,
                            current_period_end = %s,
                            cancel_at_period_end = %s
                        WHERE id = %s
                    """, (
                        stripe_subscription.status,
                        datetime.fromtimestamp(stripe_subscription.current_period_end),
                        stripe_subscription.cancel_at_period_end,
                        subscription.id
                    ))
                    conn.commit()
            
            logger.info(f"Synced subscription {subscription.id} with Stripe")
            
            return {
                'success': True,
                'status': stripe_subscription.status,
                'period_end': datetime.fromtimestamp(stripe_subscription.current_period_end).isoformat()
            }
        
        except Exception as e:
            logger.error(f"Failed to sync subscription: {str(e)}")
            raise


# Example usage
if __name__ == '__main__':
    import sys
    
    # Check required environment variables
    required_vars = ['STRIPE_SECRET_KEY', 'POSTGRES_PASSWORD']
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        print(f"Error: Missing required environment variables: {', '.join(missing_vars)}")
        sys.exit(1)
    
    # Initialize manager
    manager = SubscriptionManager()
    print("Subscription Manager initialized successfully")
