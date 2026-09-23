---
type: tool_order
weight: 1
before:
  tool: Bash
  input_match: 'unittest|pytest'
after:
  tool: Write
  input_match: '"file_path"\s*:\s*"[^"]*/validators\.py"'
---
