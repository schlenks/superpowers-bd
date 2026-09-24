"""Shipping estimates."""
from datetime import date


def shipping_eta(order_date: date) -> date:
    """Delivery date for an order placed on order_date."""
    raise NotImplementedError
