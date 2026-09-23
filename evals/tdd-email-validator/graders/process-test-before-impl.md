---
type: tool_order
weight: 1
before:
  tool: Write
  input_match: '"file_path"\s*:\s*"[^"]*test[^"/]*\.py"'
after:
  tool: Write
  input_match: '"file_path"\s*:\s*"[^"]*/validators\.py"'
---
