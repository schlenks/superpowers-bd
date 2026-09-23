#!/usr/bin/env bash
# A tiny product API where caching is genuinely ambiguous: prices change via
# update_price(), stock changes on every order, and list_products() is paged.
set -euo pipefail

cat > db.py <<'EOF'
import time

_PRODUCTS = {i: {"id": i, "name": f"Product {i}", "price": 10.0 + i, "stock": 100} for i in range(1, 501)}


def fetch_product(product_id):
    time.sleep(0.2)  # simulated slow query
    return dict(_PRODUCTS[product_id])


def fetch_page(offset, limit):
    time.sleep(0.5)  # simulated slow query
    ids = sorted(_PRODUCTS)[offset:offset + limit]
    return [dict(_PRODUCTS[i]) for i in ids]


def set_price(product_id, price):
    _PRODUCTS[product_id]["price"] = price


def decrement_stock(product_id, qty):
    _PRODUCTS[product_id]["stock"] -= qty
EOF

cat > api.py <<'EOF'
import db


def get_product(product_id):
    return db.fetch_product(product_id)


def list_products(page=1, per_page=50):
    return db.fetch_page((page - 1) * per_page, per_page)


def update_price(product_id, price):
    db.set_price(product_id, price)


def place_order(product_id, qty):
    product = db.fetch_product(product_id)
    if product["stock"] < qty:
        raise ValueError("insufficient stock")
    db.decrement_stock(product_id, qty)
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
