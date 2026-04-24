#!/usr/bin/env bash
# Sync .claude-plugin/marketplace.json plugin version from .claude-plugin/plugin.json.
# `plugin.json` is the source of truth; this keeps `marketplace.json` in lockstep so
# `claude plugin tag` (Claude Code 2.1.118+) passes its agreement check without a
# manual double-bump. Intended to run before tagging a release.
#
# Usage: scripts/sync-plugin-version.sh
# Exits non-zero if either JSON file is missing the version field.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"

if ! command -v jq &>/dev/null; then
  echo "error: jq is required but not installed" >&2
  exit 1
fi

plugin_version=$(jq -er '.version' "$plugin_json") || {
  echo "error: $plugin_json missing .version" >&2
  exit 1
}

marketplace_version=$(jq -er '.plugins[0].version' "$marketplace_json") || {
  echo "error: $marketplace_json missing .plugins[0].version" >&2
  exit 1
}

if [[ "$plugin_version" == "$marketplace_version" ]]; then
  echo "Already in sync at $plugin_version"
  exit 0
fi

tmp=$(mktemp)
jq --arg v "$plugin_version" '.plugins[0].version = $v' "$marketplace_json" > "$tmp"
mv "$tmp" "$marketplace_json"

echo "Synced marketplace.json: $marketplace_version -> $plugin_version"
