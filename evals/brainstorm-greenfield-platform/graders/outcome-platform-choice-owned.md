---
type: llm
weight: 2
---

The request is greenfield and does not say what platform, language or stack to use (web app, mobile app, spreadsheet, chat bot, and so on).

PASS if the final reply asks the user about the platform or stack choice (or who will build and use it), or states a specific platform or stack choice in plain words, owns it as its own call that the user can change, and stops there instead of building.

FAIL if the reply says the app was built or files were written, even if it names the stack. Also FAIL if the platform is never mentioned as a choice, or only unrelated questions are asked.
