#!/usr/bin/env python3
"""
Horizen Network - Stripe Payment Integration
Handles Stripe API interactions for payment processing
"""

import os
import stripe
import logging
from typing import Dict, Optional, List
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Stripe
stripe.api_key = os.getenv('STRIPE_SECRET_KEY')
stripe.api_version = '2023-10-16'

# Product pricing IDs
DRUID_GENIESS_PRICE_ID = os.getenv('STRIPE_DRUID_GENIESS_PRICE_ID', 'price_druid_geniess_monthly')
ENTITY_PRICE_ID = os.getenv('STRIPE_ENTITY_PRICE_ID', 'price_entity_monthly')

# Price configurations (in cents)
PRICING = {
    'druid_geniess': {
        'price_id': DRUID_GENIESS_PRICE_ID,
        'amount': 1500,  # $15.00
        'currency': 'usd',
        'interval': 'month',
        'name': 'Druid + Geniess Bundle',
        'description': 'Access to Druid analytics and Geniess intelligence platform'
    },
    'entity': {
        'price_id': ENTITY_PRICE_ID,
        'amount': 500,  # $5.00
        'currency': 'usd',
        'interval': 'month',
        'name': 'Entity AI',
        'description': 'Access to Entity AI web application'
    }
}


class StripePaymentService:
    """Service for handling Stripe payment operations"""
    
    def __init__(self):
        if not stripe.api_key:
            raise ValueError("STRIPE_SECRET_KEY environment variable not set")
        logger.info("Stripe Payment Service initialized")
    
    def create_customer(self, email: str, name: Optional[str] = None, 
                       metadata: Optional[Dict] = None) -> stripe.Customer:
        """
        Create a new Stripe customer
        
        Args:
            email: Customer email address
            name: Customer name (optional)
            metadata: Additional metadata (optional)
        
        Returns:
            Stripe Customer object
        """
        try:
            customer_data = {
                'email': email,
                'metadata': metadata or {}
            }
            
            if name:
                customer_data['name'] = name
            
            customer = stripe.Customer.create(**customer_data)
            logger.info(f"Created Stripe customer: {customer.id} ({email})")
            return customer
        
        except stripe.error.StripeError as e:
            logger.error(f"Failed to create customer: {str(e)}")
            raise
    
    def get_customer(self, customer_id: str) -> Optional[stripe.Customer]:
        """
        Retrieve a Stripe customer by ID
        
        Args:
            customer_id: Stripe customer ID
        
        Returns:
            Stripe Customer object or None if not found
        """
        try:
            return stripe.Customer.retrieve(customer_id)
        except stripe.error.InvalidRequestError:
            logger.warning(f"Customer not found: {customer_id}")
            return None
        except stripe.error.StripeError as e:
            logger.error(f"Failed to retrieve customer: {str(e)}")
            raise
    
    def update_customer(self, customer_id: str, **kwargs) -> stripe.Customer:
        """
        Update a Stripe customer
        
        Args:
            customer_id: Stripe customer ID
            **kwargs: Fields to update
        
        Returns:
            Updated Stripe Customer object
        """
        try:
            customer = stripe.Customer.modify(customer_id, **kwargs)
            logger.info(f"Updated customer: {customer_id}")
            return customer
        except stripe.error.StripeError as e:
            logger.error(f"Failed to update customer: {str(e)}")
            raise
    
    def create_subscription(self, customer_id: str, plan_type: str, 
                          trial_days: Optional[int] = None) -> stripe.Subscription:
        """
        Create a subscription for a customer
        
        Args:
            customer_id: Stripe customer ID
            plan_type: Plan type ('druid_geniess' or 'entity')
            trial_days: Number of trial days (optional)
        
        Returns:
            Stripe Subscription object
        """
        if plan_type not in PRICING:
            raise ValueError(f"Invalid plan type: {plan_type}")
        
        try:
            subscription_data = {
                'customer': customer_id,
                'items': [{'price': PRICING[plan_type]['price_id']}],
                'payment_behavior': 'default_incomplete',
                'payment_settings': {
                    'save_default_payment_method': 'on_subscription'
                },
                'expand': ['latest_invoice.payment_intent'],
                'metadata': {
                    'plan_type': plan_type
                }
            }
            
            if trial_days and trial_days > 0:
                subscription_data['trial_period_days'] = trial_days
            
            subscription = stripe.Subscription.create(**subscription_data)
            logger.info(f"Created subscription: {subscription.id} for customer {customer_id}")
            return subscription
        
        except stripe.error.StripeError as e:
            logger.error(f"Failed to create subscription: {str(e)}")
            raise
    
    def get_subscription(self, subscription_id: str) -> Optional[stripe.Subscription]:
        """
        Retrieve a subscription by ID
        
        Args:
            subscription_id: Stripe subscription ID
        
        Returns:
            Stripe Subscription object or None if not found
        """
        try:
            return stripe.Subscription.retrieve(subscription_id)
        except stripe.error.InvalidRequestError:
            logger.warning(f"Subscription not found: {subscription_id}")
            return None
        except stripe.error.StripeError as e:
            logger.error(f"Failed to retrieve subscription: {str(e)}")
            raise
    
    def cancel_subscription(self, subscription_id: str, 
                          at_period_end: bool = True) -> stripe.Subscription:
        """
        Cancel a subscription
        
        Args:
            subscription_id: Stripe subscription ID
            at_period_end: Cancel at end of billing period (True) or immediately (False)
        
        Returns:
            Updated Stripe Subscription object
        """
        try:
            if at_period_end:
                subscription = stripe.Subscription.modify(
                    subscription_id,
                    cancel_at_period_end=True
                )
                logger.info(f"Subscription {subscription_id} will cancel at period end")
            else:
                subscription = stripe.Subscription.delete(subscription_id)
                logger.info(f"Subscription {subscription_id} cancelled immediately")
            
            return subscription
        
        except stripe.error.StripeError as e:
            logger.error(f"Failed to cancel subscription: {str(e)}")
            raise
    
    def reactivate_subscription(self, subscription_id: str) -> stripe.Subscription:
        """
        Reactivate a cancelled subscription (if not yet ended)
        
        Args:
            subscription_id: Stripe subscription ID
        
        Returns:
            Updated Stripe Subscription object
        """
        try:
            subscription = stripe.Subscription.modify(
                subscription_id,
                cancel_at_period_end=False
            )
            logger.info(f"Reactivated subscription: {subscription_id}")
            return subscription
        except stripe.error.StripeError as e:
            logger.error(f"Failed to reactivate subscription: {str(e)}")
            raise
    
    def update_subscription(self, subscription_id: str, new_plan_type: str) -> stripe.Subscription:
        """
        Update subscription to a different plan
        
        Args:
            subscription_id: Stripe subscription ID
            new_plan_type: New plan type ('druid_geniess' or 'entity')
        
        Returns:
            Updated Stripe Subscription object
        """
        if new_plan_type not in PRICING:
            raise ValueError(f"Invalid plan type: {new_plan_type}")
        
        try:
            subscription = stripe.Subscription.retrieve(subscription_id)
            
            # Update subscription item
            stripe.Subscription.modify(
                subscription_id,
                items=[{
                    'id': subscription['items']['data'][0].id,
                    'price': PRICING[new_plan_type]['price_id']
                }],
                proration_behavior='create_prorations',
                metadata={'plan_type': new_plan_type}
            )
            
            logger.info(f"Updated subscription {subscription_id} to {new_plan_type}")
            return stripe.Subscription.retrieve(subscription_id)
        
        except stripe.error.StripeError as e:
            logger.error(f"Failed to update subscription: {str(e)}")
            raise
    
    def create_checkout_session(self, customer_id: str, plan_type: str, 
                               success_url: str, cancel_url: str,
                               trial_days: Optional[int] = None) -> stripe.checkout.Session:
        """
        Create a Stripe Checkout session for subscription
        
        Args:
            customer_id: Stripe customer ID
            plan_type: Plan type ('druid_geniess' or 'entity')
            success_url: URL to redirect after successful payment
            cancel_url: URL to redirect if payment cancelled
            trial_days: Number of trial days (optional)
        
        Returns:
            Stripe Checkout Session object
        """
        if plan_type not in PRICING:
            raise ValueError(f"Invalid plan type: {plan_type}")
        
        try:
            session_data = {
                'customer': customer_id,
                'payment_method_types': ['card'],
                'line_items': [{
                    'price': PRICING[plan_type]['price_id'],
                    'quantity': 1
                }],
                'mode': 'subscription',
                'success_url': success_url,
                'cancel_url': cancel_url,
                'metadata': {
                    'plan_type': plan_type
                }
            }
            
            if trial_days and trial_days > 0:
                session_data['subscription_data'] = {
                    'trial_period_days': trial_days
                }
            
            session = stripe.checkout.Session.create(**session_data)
            logger.info(f"Created checkout session: {session.id}")
            return session
        
        except stripe.error.StripeError as e:
            logger.error(f"Failed to create checkout session: {str(e)}")
            raise
    
    def create_billing_portal_session(self, customer_id: str, 
                                     return_url: str) -> stripe.billing_portal.Session:
        """
        Create a billing portal session for customer to manage subscription
        
        Args:
            customer_id: Stripe customer ID
            return_url: URL to return to after managing subscription
        
        Returns:
            Stripe Billing Portal Session object
        """
        try:
            session = stripe.billing_portal.Session.create(
                customer=customer_id,
                return_url=return_url
            )
            logger.info(f"Created billing portal session for customer: {customer_id}")
            return session
        except stripe.error.StripeError as e:
            logger.error(f"Failed to create billing portal session: {str(e)}")
            raise
    
    def list_customer_subscriptions(self, customer_id: str) -> List[stripe.Subscription]:
        """
        List all subscriptions for a customer
        
        Args:
            customer_id: Stripe customer ID
        
        Returns:
            List of Stripe Subscription objects
        """
        try:
            subscriptions = stripe.Subscription.list(
                customer=customer_id,
                limit=100
            )
            return subscriptions.data
        except stripe.error.StripeError as e:
            logger.error(f"Failed to list subscriptions: {str(e)}")
            raise
    
    def get_payment_intent(self, payment_intent_id: str) -> Optional[stripe.PaymentIntent]:
        """
        Retrieve a payment intent by ID
        
        Args:
            payment_intent_id: Stripe payment intent ID
        
        Returns:
            Stripe PaymentIntent object or None if not found
        """
        try:
            return stripe.PaymentIntent.retrieve(payment_intent_id)
        except stripe.error.InvalidRequestError:
            logger.warning(f"Payment intent not found: {payment_intent_id}")
            return None
        except stripe.error.StripeError as e:
            logger.error(f"Failed to retrieve payment intent: {str(e)}")
            raise
    
    def list_invoices(self, customer_id: str, limit: int = 10) -> List[stripe.Invoice]:
        """
        List invoices for a customer
        
        Args:
            customer_id: Stripe customer ID
            limit: Maximum number of invoices to return
        
        Returns:
            List of Stripe Invoice objects
        """
        try:
            invoices = stripe.Invoice.list(
                customer=customer_id,
                limit=limit
            )
            return invoices.data
        except stripe.error.StripeError as e:
            logger.error(f"Failed to list invoices: {str(e)}")
            raise
    
    def get_upcoming_invoice(self, customer_id: str) -> Optional[stripe.Invoice]:
        """
        Get the upcoming invoice for a customer
        
        Args:
            customer_id: Stripe customer ID
        
        Returns:
            Stripe Invoice object or None if no upcoming invoice
        """
        try:
            return stripe.Invoice.upcoming(customer=customer_id)
        except stripe.error.InvalidRequestError:
            logger.info(f"No upcoming invoice for customer: {customer_id}")
            return None
        except stripe.error.StripeError as e:
            logger.error(f"Failed to get upcoming invoice: {str(e)}")
            raise
    
    @staticmethod
    def get_pricing_info(plan_type: str) -> Dict:
        """
        Get pricing information for a plan type
        
        Args:
            plan_type: Plan type ('druid_geniess' or 'entity')
        
        Returns:
            Dictionary with pricing information
        """
        if plan_type not in PRICING:
            raise ValueError(f"Invalid plan type: {plan_type}")
        
        return PRICING[plan_type].copy()
    
    @staticmethod
    def get_all_plans() -> Dict:
        """
        Get all available plans and their pricing
        
        Returns:
            Dictionary of all plans
        """
        return PRICING.copy()


# Example usage and testing
if __name__ == '__main__':
    import sys
    
    # Check if Stripe key is configured
    if not os.getenv('STRIPE_SECRET_KEY'):
        print("Error: STRIPE_SECRET_KEY environment variable not set")
        print("Please set it before running this script")
        sys.exit(1)
    
    # Initialize service
    payment_service = StripePaymentService()
    
    # Display available plans
    print("\nAvailable Plans:")
    print("-" * 60)
    for plan_type, details in payment_service.get_all_plans().items():
        print(f"\nPlan: {details['name']}")
        print(f"  Type: {plan_type}")
        print(f"  Price: ${details['amount']/100:.2f} {details['currency'].upper()} / {details['interval']}")
        print(f"  Description: {details['description']}")
    print("-" * 60)
