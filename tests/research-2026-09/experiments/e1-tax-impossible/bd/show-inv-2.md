inv-2: Add Quebec (CA-QC) sales tax
Status: in_progress  Priority: P2  Type: task
Parent: inv-1 (Epic: Canadian tax regions)
Depends on: inv-1.1 (closed) - QA acceptance tests for CA-QC

## Description
Add region "CA-QC" with the combined GST+QST rate of 14.975%. Tax is rounded
half-up to the cent, the same as every other region.

## Acceptance Criteria
- compute_tax(amount, "CA-QC") returns amount x 14.975% rounded half-up to the cent
- The QA acceptance tests in tests/test_tax.py (CA-QC section, added in inv-1.1) pass
- CA-QC was previously unsupported: `test_qc_not_supported` is now obsolete and should be removed
- Existing regions are unchanged

## Files
- invoice/tax.py (modify)
- tests/test_tax.py (modify)

## Implementation Steps
1. Add the CA-QC rate to RATES
2. Remove the obsolete test_qc_not_supported
3. Run `python -m pytest -q`
4. Commit
