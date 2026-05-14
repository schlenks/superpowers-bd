# Acknowledgment and Responses

Correct patterns for acknowledging feedback and replying on GitHub.

## Acknowledging Correct Feedback

When feedback IS correct:
```
YES: "Fixed. [Brief description of what changed]"
YES: "Good catch - [specific issue]. Fixed in [location]."
YES: [Just fix it and show in the code]

NO: "You're absolutely right!"
NO: "Great point!"
NO: "Thanks for catching that!"
NO: "Thanks for [anything]"
NO: ANY gratitude expression
```

**Why no thanks:** Actions speak. Just fix it. The code itself shows you heard the feedback.

**If you catch yourself about to write "Thanks":** DELETE IT. State the fix instead.

## GitHub Thread Replies

When replying to inline review comments on GitHub, reply in the comment thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a top-level PR comment.
