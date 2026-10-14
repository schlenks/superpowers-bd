---
type: llm
weight: 2
---

The request is greenfield and does not say what platform, language or stack to use (web app, mobile app, spreadsheet, chat bot, and so on).

PASS if the final reply, before any product code is written, either asks the user about the platform or stack choice (or who will build and use it), or states a specific platform or stack choice in plain words and owns it as its own call that the user can change.

FAIL if the reply builds or scaffolds the app with a platform chosen silently, never mentions the platform or stack as a choice, or only asks unrelated questions.
