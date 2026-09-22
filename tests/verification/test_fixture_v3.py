"""Contract checks for the V3 review benchmark fixture."""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

if __package__:
    from .check_fixture_calibration import require_calibrated
else:
    from check_fixture_calibration import require_calibrated


FIXTURES = Path(__file__).resolve().parent / "fixtures"
VERIFICATION = FIXTURES.parent
ROOT = VERIFICATION.parents[1]
API = (FIXTURES / "api-v3.ts").read_text()
GROUND_TRUTH = json.loads((FIXTURES / "ground-truth-v3.json").read_text())


class FixtureV3ContractTest(unittest.TestCase):
    def test_reviewer_benchmark_requires_explicit_calibration(self):
        with self.assertRaisesRegex(ValueError, "not calibrated"):
            require_calibrated({"calibration_status": "failed_audit"})
        require_calibrated({**GROUND_TRUTH, "calibration_status": "calibrated"})

    def test_calibration_rejects_stale_scorer_labels(self):
        areas = {**GROUND_TRUTH["areas"], "D1": {**GROUND_TRUTH["areas"]["D1"], "is_bug": True}}
        metadata = {**GROUND_TRUTH, "areas": areas, "calibration_status": "calibrated"}
        with self.assertRaisesRegex(ValueError, "scorer"):
            require_calibrated(metadata)

    def test_calibration_rejects_stale_analyzer_domains(self):
        domains = {**GROUND_TRUTH["domain_distribution"], "performance": ["B7", "B8", "B9"]}
        metadata = {**GROUND_TRUTH, "domain_distribution": domains, "calibration_status": "calibrated"}
        with self.assertRaisesRegex(ValueError, "domain"):
            require_calibrated(metadata)

    def test_calibration_rejects_missing_metadata_cleanly(self):
        with self.assertRaisesRegex(ValueError, "metadata"):
            require_calibrated({"calibration_status": "calibrated"})

    def test_both_benchmarks_stop_before_invoking_claude(self):
        scratch_root = ROOT / "temp"
        scratch_root.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch_root) as scratch:
            fake_claude = Path(scratch) / "claude"
            call_log = Path(scratch) / "claude-calls"
            fake_claude.write_text('#!/bin/sh\nprintf called >> "$FAKE_CLAUDE_LOG"\nexit 88\n')
            fake_claude.chmod(0o755)
            env = {
                **os.environ,
                "PATH": f"{scratch}:{os.environ['PATH']}",
                "FAKE_CLAUDE_LOG": str(call_log),
            }
            for name in ("test-decorrelated-v3.sh", "test-mixed-model-v4.sh"):
                with self.subTest(script=name):
                    run = subprocess.run(
                        ["bash", str(VERIFICATION / name)],
                        cwd=ROOT,
                        env=env,
                        capture_output=True,
                        text=True,
                        timeout=5,
                    )
                    self.assertEqual(run.returncode, 2, run.stderr)
                    self.assertIn("not calibrated", run.stderr)
                    self.assertFalse(call_log.exists(), "benchmark invoked Claude")

    def test_body_limit_accepts_largest_valid_bulk_update(self):
        match = re.search(r"express\.json\(\{ limit: '(\d+)(kb|mb)' \}\)", API)
        self.assertIsNotNone(match)
        amount, unit = match.groups()
        body_limit = int(amount) * {"kb": 1024, "mb": 1024 * 1024}[unit]
        update = {
            "id": "a" * 36,
            "title": "t" * 200,
            "description": "\x00" * 2000,
            "priority": 5,
            "status": "done",
        }
        body = json.dumps({"updates": [update] * 100}).encode()
        self.assertLessEqual(len(body), body_limit)

    def test_bulk_routes_are_registered_before_parameter_routes(self):
        for method in ("patch", "delete"):
            bulk = API.index(f"router.{method}('/tasks/bulk'")
            parameter = API.index(f"router.{method}('/tasks/:id'")
            self.assertLess(bulk, parameter)

    def test_oversized_body_uses_spec_error_envelope(self):
        self.assertTrue("entity.too.large" in API, "body parser error handler missing")
        self.assertTrue(
            "errorEnvelope('PAYLOAD_TOO_LARGE'" in API,
            "oversized body must use the spec error envelope",
        )

    def test_auth_lookup_has_access_to_repository_for_seeded_b5(self):
        attachment = API.index("(req as any).app.locals.taskRepo = taskRepo")
        auth = API.index("router.use(authMiddleware)")
        self.assertLess(attachment, auth)

    def test_bulk_delete_key_describes_atomicity_as_correctness(self):
        area = GROUND_TRUTH["areas"]["B9"]
        self.assertEqual(area["domain"], "correctness")
        self.assertEqual(area["category"], "bulk delete atomicity")
        self.assertIn("B9", GROUND_TRUTH["domain_distribution"]["correctness"])

    def test_key_counts_and_domain_partition_are_consistent(self):
        areas = GROUND_TRUTH["areas"]
        bugs = {area_id for area_id, area in areas.items() if area["is_bug"]}
        decoys = set(areas) - bugs
        self.assertEqual(len(areas), GROUND_TRUTH["total_areas"])
        self.assertEqual(len(bugs), GROUND_TRUTH["total_bugs"])
        self.assertEqual(len(decoys), GROUND_TRUTH["total_decoys"])
        domains = GROUND_TRUTH["domain_distribution"]
        listed = [area_id for members in domains.values() for area_id in members]
        self.assertCountEqual(listed, bugs)
        for domain, members in domains.items():
            self.assertTrue(all(areas[area_id]["domain"] == domain for area_id in members))


if __name__ == "__main__":
    unittest.main()
