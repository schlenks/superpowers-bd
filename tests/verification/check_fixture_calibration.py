#!/usr/bin/env python3
"""Stop reviewer experiments from scoring an uncalibrated fixture."""

import ast
import json
import re
import sys
from pathlib import Path


VERIFICATION = Path(__file__).resolve().parent


def _assigned_literal(source: str, name: str):
    """Read a top-level literal assignment without executing the analyzer."""
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == name for target in node.targets
        ):
            value = node.value
            if isinstance(value, ast.Call) and isinstance(value.func, ast.Name) and value.func.id == "frozenset":
                value = value.args[0]
            return ast.literal_eval(value)
    raise ValueError(f"analyzer has no {name} definition")


def _check_scorers(metadata: dict) -> None:
    areas = metadata["areas"]
    bugs = {area_id for area_id, area in areas.items() if area["is_bug"]}
    decoys = set(areas) - bugs

    for name in ("test-decorrelated-v3.sh", "test-mixed-model-v4.sh"):
        source = (VERIFICATION / name).read_text()
        for variable, expected in (("REAL_BUGS", bugs), ("DECOYS", decoys)):
            assignments = re.findall(rf"^{variable} = \{{([^}}]*)\}}", source, re.MULTILINE)
            if not assignments or any(set(re.findall(r'"([BD]\d+)"', item)) != expected for item in assignments):
                raise ValueError(f"{name} scorer {variable} disagrees with the fixture key")

    analyzer = (VERIFICATION / "analyze-v3.py").read_text()
    for variable, expected in (("REAL_BUGS", bugs), ("DECOYS", decoys)):
        if set(_assigned_literal(analyzer, variable)) != expected:
            raise ValueError(f"analyzer scorer {variable} disagrees with the fixture key")
    domains = _assigned_literal(analyzer, "DOMAINS")
    if domains != metadata["domain_distribution"] or any(
        areas[area_id]["domain"] != domain
        for domain, members in domains.items() for area_id in members
    ):
        raise ValueError("analyzer domains disagree with the fixture key")


def require_calibrated(metadata: dict) -> None:
    if metadata.get("calibration_status") != "calibrated":
        report = metadata.get("audit_report", "the fixture audit")
        raise ValueError(f"Review fixture is not calibrated; see {report}")
    try:
        _check_scorers(metadata)
    except (AttributeError, KeyError, SyntaxError, TypeError) as error:
        raise ValueError(f"Invalid fixture metadata or scorer: {error}") from error


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: check_fixture_calibration.py <ground-truth.json>", file=sys.stderr)
        return 2
    try:
        require_calibrated(json.loads(Path(sys.argv[1]).read_text()))
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
