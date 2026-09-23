---
description: Failing test whose symptom points at client.py but whose root cause is config.py returning strings. A second, untested consumer (deadline) shares the bug, so only a root-cause fix repairs it. Outcome graders are scored in both arms.
tags: [outcome, debugging, needs-bash]
max_turns: 40
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList, TaskGet, Bash, Write, Edit]
---

`python3 -m unittest` is failing:

```
ERROR: test_default_retry_delays (test_client.ClientTest.test_default_retry_delays)
Traceback (most recent call last):
  File "test_client.py", line 9, in test_default_retry_delays
    self.assertEqual(retry_delays(load_config({})), [1, 2, 4])
  File "client.py", line 6, in retry_delays
    return [2 ** i for i in range(cfg["retries"])]
TypeError: 'str' object cannot be interpreted as an integer
```

Can you fix it?
