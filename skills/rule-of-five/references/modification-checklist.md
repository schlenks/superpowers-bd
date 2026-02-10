# Modifying Existing Code: Full Checklist

Shift the Correctness pass: **"Did I break anything?"** matters more than "Does my addition work?"

## Correctness Checklist for Modifications

1. Does my change work correctly?
2. Did I break the code I modified?
3. Did I break tests that depend on old behavior?
4. **Did I break consumers?** (Other code that calls/uses what I changed)

## Interface Changes (APIs, Error Formats, Return Types, Public Functions)

- Grep for all usages before changing behavior
- Check if consumers rely on specific field *values*, not just types
- If contract changes, ensure consumers are updated or backwards-compatible

## Warning Signs You Might Break Consumers

- Changing error message content or structure
- Changing field names or response shapes
- Changing return types or adding required parameters
- Removing fields that callers may read (even if unused by your code)

## Excellence for Modifications

For Excellence: **"Did I leave it better than I found it?"**
