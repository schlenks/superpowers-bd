---
type: regex
weight: 2
target:
  source: file
  path: rate_limiter.py
pattern: 'def allow\(self\):[\s\S]*?with self\._lock:[\s\S]*?def reset'
---
