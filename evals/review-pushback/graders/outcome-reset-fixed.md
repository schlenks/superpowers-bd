---
type: regex
weight: 1
target:
  source: file
  path: rate_limiter.py
pattern: 'def reset\(self[^)]*\):[\s\S]*_window_start\s*='
---
