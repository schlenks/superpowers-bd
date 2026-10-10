"""Extract complete JSON objects from model text without counting quoted braces."""

import json
from collections.abc import Iterator


def find_json_objects(text: str) -> Iterator[str]:
    decoder = json.JSONDecoder()
    for start, char in enumerate(text):
        if char != "{":
            continue
        try:
            value, end = decoder.raw_decode(text, start)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            yield text[start:end]
