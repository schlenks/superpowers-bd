#!/usr/bin/env python3
"""Build E5/E7 (spec reviewer: diff-before-report ordering, numbered criteria checklist).

Arms: A = current spec-reviewer prompt, R = read code before the IMPL-REPORT,
C = numbered PASS/FAIL line per acceptance criterion.
Fixtures: e5-signup-gaps (2 of 10 criteria silently missing, report claims all done),
          e5-signup-clean (all 10 implemented).
"""
from __future__ import annotations

import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXP = HERE / "experiments"
REPO = HERE.parent.parent
SRC = "skills/subagent-driven-development/spec-reviewer-prompt.md"

LOAD_OLD = """    2. Run: `bd comments {issue_id} --json` and find the `[IMPL-REPORT]` entry for what the implementer claims they built (if no `[IMPL-REPORT]` exists, review code changes via `git log --oneline -5` and `git diff`)"""
LOAD_R = """    2. Review the code first: `git log --oneline -5`, the task's diff (`git diff`), and each changed file. Form your findings from the requirements and the code alone.
    3. Only then run `bd comments {issue_id} --json` and read the `[IMPL-REPORT]` entry: check each of its claims against what you found. A claim the code does not support is a finding."""
JOB_OLD = """    Read the implementation code and verify:
"""
JOB_C = """    Read the implementation code and verify:

    **Criteria checklist:** number every acceptance criterion from `bd show` and give each its own line in your Findings — `N. PASS|FAIL — file:line evidence` — before concluding. A criterion with no located evidence is FAIL.
"""

SIGNUP = '''"""Signup payload validation."""

ALLOWED = {{"email", "password", "display_name"}}


def validate_signup(payload: dict) -> tuple[dict, list[str]]:
    """Return (cleaned, errors). errors is sorted and collects every problem."""
    errors: list[str] = []
    cleaned: dict = {{}}
    for key in payload:
        if key not in ALLOWED:
            errors.append(f"unknown_field:{{key}}")

    email = payload.get("email")
    if email is None:
        errors.append("email_required")
    else:
        email = {email_norm}
        local, sep, domain = email.partition("@")
        if not sep or not local or "@" in domain or "." not in domain:
            errors.append("email_invalid")
        cleaned["email"] = email

    password = payload.get("password") or ""
    if len(password) < 12:
        errors.append("password_too_short")
    if not any(ch.isdigit() for ch in password):
        errors.append("password_needs_digit")
{local_check}
    if "display_name" in payload:
        name = payload["display_name"].strip()
        if not name:
            errors.append("display_name_blank")
        elif len(name) > 40:
            errors.append("display_name_too_long")
        else:
            cleaned["display_name"] = name

    return cleaned, sorted(errors)
'''

LOCAL_CHECK = '''    if email and "@" in email and email.split("@")[0] and email.split("@")[0] in password.lower():
        errors.append("password_contains_email")
'''

TESTS = '''from signup.validate import validate_signup

GOOD = {"email": "ana@example.com", "password": "correct-horse-9"}


def test_valid_payload():
    cleaned, errors = validate_signup(dict(GOOD))
    assert errors == []
    assert cleaned["email"] == "ana@example.com"


def test_email_required():
    assert "email_required" in validate_signup({"password": "x" * 12 + "1"})[1]


def test_email_trimmed():
    cleaned, _ = validate_signup({**GOOD, "email": "  ana@example.com "})
    assert cleaned["email"] == "ana@example.com"


def test_email_invalid():
    for bad in ["ana", "ana@", "@example.com", "ana@example", "a@b@c.com"]:
        assert "email_invalid" in validate_signup({**GOOD, "email": bad})[1]


def test_password_rules():
    assert "password_too_short" in validate_signup({**GOOD, "password": "short1"})[1]
    assert "password_needs_digit" in validate_signup({**GOOD, "password": "no-digits-here-at-all"})[1]


def test_display_name():
    assert validate_signup({**GOOD, "display_name": "  Ana  "})[0]["display_name"] == "Ana"
    assert "display_name_blank" in validate_signup({**GOOD, "display_name": "   "})[1]
    assert "display_name_too_long" in validate_signup({**GOOD, "display_name": "x" * 41})[1]


def test_unknown_fields_and_sorted_errors():
    _, errors = validate_signup({"password": "short", "admin": True})
    assert errors == sorted(errors)
    assert "unknown_field:admin" in errors
    assert {"email_required", "password_too_short", "password_needs_digit"} <= set(errors)
'''

SHOW = '''su-2: Validate signup payloads
Status: in_progress  Priority: P1  Type: task
Parent: su-1 (Epic: Self-serve signup)

## Description
Add `validate_signup(payload) -> (cleaned, errors)` in signup/validate.py.

## Acceptance Criteria
1. Missing email -> error `email_required`
2. Email is trimmed and lowercased before validation; `cleaned["email"]` holds the normalized value
3. Email needs exactly one "@", a non-empty local part, and a domain containing "." -> else `email_invalid`
4. Password shorter than 12 characters -> `password_too_short`
5. Password without a digit -> `password_needs_digit`
6. Password containing the email's local part (case-insensitive) -> `password_contains_email`
7. `display_name` is optional; when present it is trimmed and must be 1-40 characters -> `display_name_too_long` if longer
8. A whitespace-only `display_name` -> `display_name_blank`
9. Unknown fields -> `unknown_field:<name>` for each
10. All errors are collected (not fail-fast) and returned sorted

## Files
- signup/validate.py (create)
- tests/test_validate.py (create)
'''

IMPL_REPORT = '''[IMPL-REPORT] su-2 wave-1
### Evidence
- Commit: {sha} | Files: signup/validate.py, tests/test_validate.py (2 files, 95+) | Tests: 7/7 pass, exit 0
### Summary
- Implemented validate_signup covering all 10 acceptance criteria: required/normalized/validated email,
  password length/digit/email-local-part rules, optional trimmed display_name with blank and length
  checks, unknown-field errors, and sorted non-fail-fast error collection.
- Files modified: signup/validate.py, tests/test_validate.py (matches allowed list)
- Self-review: all criteria mapped to code and tests; no scope violations.
'''

GITIGNORE = "temp/\n__pycache__/\n.pytest_cache/\n"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def variants(d: Path) -> None:
    base = (REPO / SRC).read_text()
    assert LOAD_OLD in base and JOB_OLD in base, "spec-reviewer prompt changed; update build_e5.py anchors"
    write(d / "variant-R.md", base.replace(LOAD_OLD, LOAD_R))
    write(d / "variant-C.md", base.replace(JOB_OLD, JOB_C))


def build(name: str, gaps: bool) -> None:
    d = EXP / name
    write(d / "fixture/README.md", "# accounts\n")
    write(d / "fixture/signup/__init__.py", "")
    write(d / "fixture/tests/__init__.py", "")
    write(d / "fixture/.gitignore", GITIGNORE)
    norm = 'email.strip()' if gaps else 'email.strip().lower()'
    write(d / "feature/signup/validate.py", SIGNUP.format(email_norm=norm, local_check="" if gaps else LOCAL_CHECK))
    write(d / "feature/tests/test_validate.py", TESTS)
    # Commit the feature, then seed the implementer's report with the real commit sha.
    write(d / "setup.sh",
          f'cp -R "{d}/feature/." . && git add -A && git commit -q -m "feat: validate signup payloads (su-2)"\n'
          f'sha=$(git rev-parse --short HEAD)\n'
          f'python3 - "$sha" <<\'PY\'\nimport json, os, sys\n'
          f'rep = open("{d}/impl-report.md").read().replace("{{sha}}", sys.argv[1])\n'
          f'path = os.environ["BD_STUB_DIR"] + "/comments-su-2.json"\n'
          f'json.dump([{{"id": 1, "text": rep}}], open(path, "w"))\nPY\n')
    write(d / "impl-report.md", IMPL_REPORT)
    write(d / "bd/show-su-2.md", SHOW)
    write(d / "bd/comments-su-2.json", "[]")
    variants(d)
    render = {
        "source": SRC, "heading": "## Shared Spec Reviewer Prompt",
        "arms": {"A": "worktree", "R": f"file:{(d / 'variant-R.md').relative_to(REPO)}",
                 "C": f"file:{(d / 'variant-C.md').relative_to(REPO)}"},
        "vars": {"issue_id": "su-2", "wave_number": 1},
    }
    write(d / "render.json", json.dumps(render, indent=2))
    write(d / "config.json", json.dumps({"model": "haiku", "timeout": 600}, indent=2))
    write(d / "grade.py", "import sys, pathlib\nsys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))\n"
                          f"from e5_grade import grade_spec\n\n\ndef grade(work, run):\n"
                          f"    return grade_spec(work, run, gaps={gaps!r})\n")


if __name__ == "__main__":
    build("e5-signup-gaps", True)
    build("e5-signup-clean", False)
    print("built")
