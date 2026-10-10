"""Contract checks for the V3 review benchmark fixture."""

import json
import csv
import os
import re
import shutil
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
DEPICTED_TESTS = (FIXTURES / "tests-v3.md").read_text()


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
            failed_key = Path(scratch) / "failed-key.json"
            failed_key.write_text(json.dumps({"calibration_status": "failed_audit"}))
            env = {
                **os.environ,
                "PATH": f"{scratch}:{os.environ['PATH']}",
                "FAKE_CLAUDE_LOG": str(call_log),
                "SPBD_TEST_GROUND_TRUTH_FILE": str(failed_key),
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

    def test_benchmarks_preserve_artifacts_and_exclude_invalid_answers(self):
        scratch_root = ROOT / "temp"
        scratch_root.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch_root) as scratch:
            # Calibrate only an isolated copy to exercise the scorer with a fake
            # CLI. The real fixture must continue to block model experiments.
            verification = Path(scratch) / "verification"
            verification.mkdir()
            for name in (
                "test-decorrelated-v3.sh", "test-mixed-model-v4.sh",
                "test-helpers.sh", "check_fixture_calibration.py",
                "analyze-v3.py", "analyze-v4.py", "json_blocks.py",
                "count-paired-cycles.py",
            ):
                shutil.copy2(VERIFICATION / name, verification / name)
            shutil.copytree(FIXTURES, verification / "fixtures")
            key = verification / "fixtures" / "ground-truth-v3.json"
            key.write_text(json.dumps({**GROUND_TRUTH, "calibration_status": "calibrated"}))
            fake_claude = Path(scratch) / "claude"
            fake_claude.write_text("""#!/usr/bin/env python3
import json
import sys
import os
if '--version' in sys.argv:
    print('fake-claude')
    raise SystemExit(0)
mode = os.environ['FAKE_RESPONSE']
if mode == 'failed':
    raise SystemExit(9)
if mode == 'malformed':
    print('{')
    raise SystemExit(0)
model = 'claude-opus-5' if '--model' in sys.argv and sys.argv[sys.argv.index('--model') + 1] == 'opus' else 'claude-sonnet-5'
areas = {name: {'found': name.startswith('B'), 'summary': 'missing {task brace'} for name in [*[f'B{i}' for i in range(1, 13)], *[f'D{i}' for i in range(1, 17)]]}
if mode == 'incomplete':
    del areas['D7']
print(json.dumps({'result': json.dumps({'areas': areas}), 'modelUsage': {model: {'canonicalModel': model}}, 'is_error': False, 'usage': {}, 'duration_ms': 1, 'total_cost_usd': 0}))
""")
            fake_claude.chmod(0o755)
            env = {
                **os.environ,
                "PATH": f"{scratch}:{os.environ['PATH']}",
                "SPBD_BENCH_CYCLES": "1",
                "SPBD_BENCH_RUN_ROOT": str(Path(scratch) / "runs"),
            }
            for mode in ("incomplete", "malformed", "failed", "complete"):
                for name, expected_runs in (("test-decorrelated-v3.sh", 8), ("test-mixed-model-v4.sh", 6)):
                    with self.subTest(script=name, response=mode):
                        run = subprocess.run(
                            ["/bin/bash", str(verification / name)],
                            cwd=ROOT,
                            env={**env, "FAKE_RESPONSE": mode},
                            capture_output=True,
                            text=True,
                            timeout=30,
                        )
                        self.assertEqual(run.returncode, 0, run.stderr)
                        valid = mode == "complete"
                        self.assertIn(f"Descriptive pilot only: {int(valid)} complete pairs", run.stdout)
                        artifact_match = re.search(r"Run artifacts retained at: (.+)", run.stdout)
                        self.assertIsNotNone(artifact_match)
                        artifacts = Path(artifact_match.group(1))
                        with (artifacts / "scores.csv").open(newline="") as source:
                            scores = list(csv.DictReader(source))
                        self.assertEqual(len(scores), expected_runs)
                        self.assertTrue(all(row["parse_ok"] == str(valid).lower() for row in scores))
                        if valid:
                            self.assertTrue(all(row["tp"] == "12" and row["fp"] == "0" for row in scores))
                        with (artifacts / "results.csv").open(newline="") as source:
                            results = list(csv.DictReader(source))
                        self.assertEqual(len(results), expected_runs)
                        self.assertTrue(all(row["attempt"] == "1" for row in results))
                        expected_status = "failed" if mode == "failed" else "succeeded"
                        self.assertTrue(all(row["status"] == expected_status for row in results))
                        self.assertTrue((artifacts / "fixture.sha256").exists())
                        self.assertEqual(len(list(artifacts.glob("prompt-*.txt"))), expected_runs)
                        self.assertEqual(len(list(artifacts.glob("output-*-attempt1.txt"))), expected_runs)

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

    def test_auth_precedes_body_parsing_and_parse_errors_use_envelope(self):
        auth = API.index("router.use(authMiddleware)")
        parser = API.index("router.use(express.json")
        self.assertLess(auth, parser)
        self.assertIn("entity.parse.failed", API)
        self.assertIn("errorEnvelope('VALIDATION_ERROR'", API)

    def test_api_scopes_task_repository_calls_to_authenticated_user(self):
        self.assertIn("taskRepo.findAll(userId)", API)
        self.assertIn("taskRepo.findByStatus(status, userId)", API)
        self.assertIn("taskRepo.findById(req.params.id, userId)", API)
        self.assertIn("owner_id: userId", API)

    def test_api_records_successful_mutations_and_webhook_failure(self):
        self.assertFalse("router.use(auditLogger)" in API, "auditLogger must not run before mutation")
        self.assertIn("recordAudit(req", API)
        self.assertIn("recordWebhookFailure(url", API)

    def test_bulk_delete_key_describes_atomicity_as_correctness(self):
        area = GROUND_TRUTH["areas"]["B9"]
        self.assertEqual(area["domain"], "correctness")
        self.assertEqual(area["category"], "bulk delete atomicity")
        self.assertIn("B9", GROUND_TRUTH["domain_distribution"]["correctness"])

    def test_depicted_suite_covers_body_boundaries_without_webhook_tests(self):
        rows = re.findall(r"^\|\s*(\d+)\s*\|([^|]+)\|\s*PASS\s*\|$", DEPICTED_TESTS, re.MULTILINE)
        self.assertEqual([int(number) for number, _ in rows], list(range(1, 67)))
        self.assertIn("**Total tests:** 66", DEPICTED_TESTS)
        self.assertIn("**Pass rate:** 66/66", DEPICTED_TESTS)
        self.assertIn("413 PAYLOAD_TOO_LARGE", rows[62][1])
        self.assertIn("100-item bulk update", rows[65][1])
        self.assertFalse(any("webhook" in description.lower() for _, description in rows))

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
