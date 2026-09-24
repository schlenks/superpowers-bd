"""Signup payload validation."""

ALLOWED = {"email", "password", "display_name"}


def validate_signup(payload: dict) -> tuple[dict, list[str]]:
    """Return (cleaned, errors). errors is sorted and collects every problem."""
    errors: list[str] = []
    cleaned: dict = {}
    for key in payload:
        if key not in ALLOWED:
            errors.append(f"unknown_field:{key}")

    email = payload.get("email")
    if email is None:
        errors.append("email_required")
    else:
        email = email.strip().lower()
        local, sep, domain = email.partition("@")
        if not sep or not local or "@" in domain or "." not in domain:
            errors.append("email_invalid")
        cleaned["email"] = email

    password = payload.get("password") or ""
    if len(password) < 12:
        errors.append("password_too_short")
    if not any(ch.isdigit() for ch in password):
        errors.append("password_needs_digit")
    if email and "@" in email and email.split("@")[0] and email.split("@")[0] in password.lower():
        errors.append("password_contains_email")

    if "display_name" in payload:
        name = payload["display_name"].strip()
        if not name:
            errors.append("display_name_blank")
        elif len(name) > 40:
            errors.append("display_name_too_long")
        else:
            cleaned["display_name"] = name

    return cleaned, sorted(errors)
