"""Behavior checks for ownership in the V3 review repository fixture."""

import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tests/verification/fixtures/repository-v3.ts"


class RepositoryV3OwnershipTest(unittest.TestCase):
    def run_repository_script(self, script: str) -> None:
        # The standalone fixture has no node_modules. Supply Node's UUID function
        # at the import boundary while executing the otherwise unchanged source.
        scratch_root = ROOT / "temp"
        scratch_root.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=scratch_root) as scratch:
            module = Path(scratch) / "repository-v3.ts"
            source = SOURCE.read_text()
            dependency = "import { v4 as uuidv4 } from 'uuid';"
            self.assertIn(dependency, source)
            module.write_text(
                source.replace(dependency, "import { randomUUID as uuidv4 } from 'node:crypto';")
            )
            process = subprocess.run(
                [
                    "node",
                    "--experimental-strip-types",
                    "--input-type=module",
                    "-e",
                    script,
                    module.as_uri(),
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(process.returncode, 0, process.stderr)

    def test_owner_scopes_reads_mutations_and_existence(self):
        self.run_repository_script(
            """
import assert from 'node:assert/strict';
const { TaskRepository } = await import(process.argv[1]);
const repo = new TaskRepository();
const alice = repo.create({ title: 'Alice task', owner_id: 'alice' });
const bob = repo.create({ title: 'Bob task', owner_id: 'bob', status: 'done' });
assert.equal(alice.owner_id, 'alice');
assert.deepEqual(repo.findAll('alice').map(t => t.id), [alice.id]);
assert.deepEqual(repo.findAll('bob').map(t => t.id), [bob.id]);
assert.deepEqual(repo.findByStatus('done', 'alice'), []);
assert.deepEqual(repo.findByStatus('done', 'bob').map(t => t.id), [bob.id]);
assert.equal(repo.findById(bob.id, 'alice'), null);
assert.equal(repo.findById(bob.id, 'bob')?.id, bob.id);
assert.equal(repo.update(bob.id, 'alice', { title: 'stolen' }), null);
assert.equal(repo.findById(bob.id, 'bob')?.title, 'Bob task');
assert.equal(repo.update(alice.id, 'alice', { status: 'done' })?.status, 'done');
assert.deepEqual(repo.findByStatus('done', 'alice').map(t => t.id), [alice.id]);
assert.equal(repo.delete(bob.id, 'alice'), false);
assert.equal(repo.exists(bob.id, 'alice'), false);
assert.equal(repo.exists(bob.id, 'bob'), true);
assert.equal(repo.existsAcrossUsers(bob.id), true);
assert.equal(repo.delete(bob.id, 'bob'), true);
assert.equal(repo.exists(bob.id, 'bob'), false);
assert.equal(repo.existsAcrossUsers(bob.id), false);
assert.equal(repo.findById(bob.id, 'bob'), null);
assert.deepEqual(repo.findAll('bob'), []);
"""
        )

    def test_seeded_raw_reference_defect_remains_observable(self):
        self.run_repository_script(
            """
import assert from 'node:assert/strict';
const { TaskRepository } = await import(process.argv[1]);
const repo = new TaskRepository();
const task = repo.create({ title: 'Original', owner_id: 'alice' });
repo.findById(task.id, 'alice').title = 'Mutated without update';
assert.equal(repo.findAll('alice')[0].title, 'Mutated without update');
"""
        )

    def test_seeded_status_full_scan_remains_observable(self):
        source = SOURCE.read_text()
        method = source.split("findByStatus(", 1)[1].split("// ─── Update", 1)[0]
        self.assertIn("this.tasks.values()", method)
        self.assertNotIn("this.statusIndex.get(status)", method)


if __name__ == "__main__":
    unittest.main()
