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

function assertSameFile(left, right, message) {
  assert(fs.readFileSync(left, 'utf8') === fs.readFileSync(right, 'utf8'), message);
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
const fallbackCli = path.join(root, '.codex', 'superpowers-bd-codex');
assert(fs.existsSync(fallbackCli), 'Superpowers-BD fallback CLI exists');
assert((fs.statSync(fallbackCli).mode & 0o111) !== 0, 'Superpowers-BD fallback CLI is executable');
assert(!fs.existsSync(path.join(root, '.codex', 'superpowers-codex')), 'old Superpowers fallback CLI is not bundled');
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
assert(entry.source.source === 'local', 'marketplace source is local');
assert(entry.source.path === './plugins/superpowers-bd', 'marketplace source path is non-empty plugin directory');

const pluginRoot = path.resolve(path.dirname(marketplacePath), '..', '..', entry.source.path);
assert(fs.existsSync(path.join(pluginRoot, '.codex-plugin', 'plugin.json')), 'marketplace source path resolves to plugin manifest');
assert(fs.existsSync(path.join(pluginRoot, 'skills', 'using-superpowers', 'SKILL.md')), 'marketplace source path resolves to plugin skills');
assert(!fs.lstatSync(path.join(pluginRoot, '.codex-plugin')).isSymbolicLink(), 'plugin manifest directory is not a symlink');
assert(!fs.lstatSync(path.join(pluginRoot, 'skills')).isSymbolicLink(), 'plugin skills directory is not a symlink');
assertSameFile(manifestPath, path.join(pluginRoot, '.codex-plugin', 'plugin.json'), 'plugin wrapper manifest mirrors root manifest');
for (const entry of fs.readdirSync(path.join(root, 'skills'), { withFileTypes: true })) {
  if (!entry.isDirectory()) continue;
  const sourceSkill = path.join(root, 'skills', entry.name, 'SKILL.md');
  if (!fs.existsSync(sourceSkill)) continue;
  const wrapperSkill = path.join(pluginRoot, 'skills', entry.name, 'SKILL.md');
  assert(fs.existsSync(wrapperSkill), `plugin wrapper bundles ${entry.name}`);
  assertSameFile(sourceSkill, wrapperSkill, `plugin wrapper ${entry.name} SKILL.md mirrors root skill`);
}
NODE

echo ""
echo "=== Codex plugin manifest tests passed ==="
