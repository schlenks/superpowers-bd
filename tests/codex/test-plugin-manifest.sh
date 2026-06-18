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
const skillDirs = fs.readdirSync(path.join(root, 'skills'), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => fs.existsSync(path.join(root, 'skills', name, 'SKILL.md')))
  .sort();
for (const skillName of skillDirs) {
  const metadataPath = path.join(root, 'skills', skillName, 'agents', 'openai.yaml');
  const text = fs.existsSync(metadataPath) ? fs.readFileSync(metadataPath, 'utf8') : '';
  assert(Boolean(text), `${skillName} has Codex UI metadata`);
  assert(/interface:\n/.test(text), `${skillName} metadata declares interface`);
  assert(/display_name: ".+"/.test(text), `${skillName} metadata has display name`);
  assert(/short_description: ".{8,80}"/.test(text), `${skillName} metadata has concise short description`);
  assert(/brand_color: "#[0-9A-Fa-f]{6}"/.test(text), `${skillName} metadata has brand color`);
  assert(/default_prompt: ".{1,128}"/.test(text), `${skillName} metadata has short default prompt`);
  assert(/policy:\n  allow_implicit_invocation: (true|false)/.test(text), `${skillName} metadata has invocation policy`);
}
assert(Array.isArray(manifest.interface.defaultPrompt) && manifest.interface.defaultPrompt.length > 0, 'manifest includes default prompts');
assert(manifest.interface.defaultPrompt.every((prompt) => prompt.length <= 128), 'default prompts fit Codex limit');
assert(manifest.interface.defaultPrompt.some((prompt) => prompt.includes('$verification-before-completion')), 'manifest includes verification prompt');
assert(manifest.interface.longDescription.includes('active model inheritance'), 'manifest describes Codex active model inheritance');

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
assert(fs.existsSync(path.join(pluginRoot, 'agents', 'code-reviewer.md')), 'marketplace source path resolves to plugin Codex agents');
assert(fs.existsSync(path.join(pluginRoot, 'hooks.json')), 'marketplace source path resolves to plugin Codex hooks');
assert(fs.existsSync(path.join(pluginRoot, 'hooks', 'hooks.json')), 'marketplace source path resolves to plugin lifecycle hook config');
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
  const sourceMetadata = path.join(root, 'skills', entry.name, 'agents', 'openai.yaml');
  const wrapperMetadata = path.join(pluginRoot, 'skills', entry.name, 'agents', 'openai.yaml');
  assert(fs.existsSync(wrapperMetadata), `plugin wrapper bundles ${entry.name} Codex metadata`);
  assertSameFile(sourceMetadata, wrapperMetadata, `plugin wrapper ${entry.name} Codex metadata mirrors root skill`);
}

for (const [file, name] of Object.entries({
  'code-reviewer.md': 'code_reviewer',
  'spec-reviewer.md': 'spec_reviewer',
  'review-aggregator.md': 'review_aggregator',
  'epic-verifier.md': 'epic_verifier',
})) {
  const agentPath = path.join(pluginRoot, 'agents', file);
  const text = fs.readFileSync(agentPath, 'utf8');
  assert(new RegExp(`^name: ${name}$`, 'm').test(text), `plugin wrapper agent ${name} declares native Codex name`);
  assert(!/^model:/m.test(text) && !/gpt-5\./.test(text), `plugin wrapper agent ${name} inherits active Codex model`);
}

const pluginHooks = readJson(path.join(pluginRoot, 'hooks.json'));
const lifecycleHooks = readJson(path.join(pluginRoot, 'hooks', 'hooks.json'));
assert(pluginHooks.hooks?.SessionStart?.[0]?.hooks?.[0]?.command === './hooks/codex-session-start.sh', 'plugin wrapper bundles SessionStart hook command');
assert(pluginHooks.hooks?.PostToolUse?.[0]?.hooks?.[0]?.command === './hooks/codex-post-tool-use.sh', 'plugin wrapper bundles PostToolUse hook command');
assert(JSON.stringify(pluginHooks) === JSON.stringify(lifecycleHooks), 'plugin wrapper mirrors hooks.json into hooks/hooks.json lifecycle config');
assert(pluginHooks.hooks?.UserPromptSubmit?.[0]?.hooks?.[0]?.command === './hooks/codex-work-state-anchor.sh', 'plugin wrapper bundles UserPromptSubmit hook command');
assert(pluginHooks.hooks?.PreCompact?.[0]?.hooks?.[0]?.command === './hooks/codex-pre-compact.sh', 'plugin wrapper bundles PreCompact hook command');
assert(pluginHooks.hooks?.Stop?.[0]?.hooks?.[0]?.command === './hooks/codex-stop-gate.sh', 'plugin wrapper bundles Stop hook command');
assert(pluginHooks.hooks?.SubagentStop?.[0]?.hooks?.[0]?.command === './hooks/codex-verdict-audit.sh', 'plugin wrapper bundles SubagentStop hook command');
for (const hookName of ['codex-session-start.sh', 'codex-post-tool-use.sh', 'codex-work-state-anchor.sh', 'codex-pre-compact.sh', 'codex-stop-gate.sh', 'codex-verdict-audit.sh']) {
  const hookPath = path.join(pluginRoot, 'hooks', hookName);
  assert(fs.existsSync(hookPath), `plugin wrapper bundles ${hookName}`);
  assert((fs.statSync(hookPath).mode & 0o111) !== 0, `plugin wrapper ${hookName} is executable`);
}
NODE

echo ""
echo "=== Codex plugin manifest tests passed ==="
