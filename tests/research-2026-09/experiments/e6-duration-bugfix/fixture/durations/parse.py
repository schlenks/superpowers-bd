"""Human duration strings like "1h30m" -> seconds."""
import re

_UNIT = {"h": 3600, "m": 60, "s": 1}
_TOKEN = re.compile(r"(\d+)([hms])")


def parse_duration(text: str) -> int:
    """Parse "<n>h<n>m<n>s" (each part optional, at least one present) into seconds."""
    text = text.strip().lower()
    if not text:
        raise ValueError("empty duration")
    total = 0
    pos = 0
    for m in _TOKEN.finditer(text):
        if m.start() != pos:
            raise ValueError(f"bad duration: {text!r}")
        total += int(m.group(1)) * _UNIT[m.group(2)]
        pos = m.end()
    if pos != len(text):
        raise ValueError(f"bad duration: {text!r}")
    return total
