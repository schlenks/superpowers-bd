#!/usr/bin/env bash
# Test: Codex plugin manifest and marketplace shape
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== Test: Codex Plugin Manifest ==="

node <<'NODE'
const fs = require('fs');
const path = require('path');

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function assert(condition, message) {
  if (!condition) {
    console.error(`  [FAIL] ${message}`);
    process.exit(1);
  }
  console.log(`  [PASS] ${message}`);
}

const root = process.cwd();
const manifestPath = path.join(root, '.codex-plugin', 'plugin.json');
assert(fs.existsSync(manifestPath), '.codex-plugin/plugin.json exists');

const manifest = readJson(manifestPath);
assert(manifest.name === 'superpowers-bd', 'manifest name is superpowers-bd');
assert(manifest.skills === './skills/', 'manifest exposes ./skills/');
assert(fs.existsSync(path.join(root, manifest.skills, 'using-superpowers', 'SKILL.md')), 'skills path resolves to bundled skills');
for (const skillName of ['using-superpowers', 'plan2beads', 'ad-hoc-code-review', 'subagent-driven-development']) {
  assert(fs.existsSync(path.join(root, 'skills', skillName, 'agents', 'openai.yaml')), `${skillName} has Codex UI metadata`);
}
assert(Array.isArray(manifest.interface.defaultPrompt) && manifest.interface.defaultPrompt.length > 0, 'manifest includes default prompts');
assert(manifest.interface.defaultPrompt.every((prompt) => prompt.length <= 128), 'default prompts fit Codex limit');

const marketplacePath = path.join(root, '.agents', 'plugins', 'marketplace.json');
assert(fs.existsSync(marketplacePath), '.agents/plugins/marketplace.json exists');

const marketplace = readJson(marketplacePath);
const entry = marketplace.plugins.find((plugin) => plugin.name === 'superpowers-bd');
assert(Boolean(entry), 'marketplace contains superpowers-bd entry');
assert(entry.policy.installation === 'AVAILABLE', 'marketplace installation policy is AVAILABLE');
assert(entry.policy.authentication === 'ON_INSTALL', 'marketplace authentication policy is ON_INSTALL');

const pluginRoot = path.resolve(path.dirname(marketplacePath), '..', '..', entry.source.path);
assert(fs.existsSync(path.join(pluginRoot, '.codex-plugin', 'plugin.json')), 'marketplace source path resolves to plugin manifest');
NODE

echo ""
echo "=== Codex plugin manifest tests passed ==="
