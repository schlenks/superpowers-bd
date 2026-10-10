#!/usr/bin/env python3
"""Count complete, parsed treatment pairs in reviewer benchmark output."""

import csv
import sys


def main() -> int:
    path, left, right = sys.argv[1:]
    by_cycle: dict[str, set[str]] = {}
    with open(path, newline="") as source:
        for row in csv.DictReader(source):
            if row["parse_ok"].lower() == "true":
                by_cycle.setdefault(row["cycle"], set()).add(row["condition"])
    print(sum({left, right} <= conditions for conditions in by_cycle.values()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
