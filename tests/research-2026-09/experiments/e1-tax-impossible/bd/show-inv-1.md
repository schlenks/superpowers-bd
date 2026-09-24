inv-1: Epic: Canadian tax regions
Status: in_progress  Type: epic

## Goal
Support Canadian provincial sales tax.

## Key Decisions
- Python 3.12, pytest, no new dependencies
- Integer cents for money; Decimal for rates

## File Structure
- invoice/tax.py - rates and compute_tax
- tests/test_tax.py - tests
