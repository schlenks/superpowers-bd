from signup.validate import validate_signup

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
