#!/usr/bin/env bash
# Copy plugin agents/skills WITH hooks to project's .claude/ directory.
# Workaround for https://github.com/anthropics/claude-code/issues/17688
# where frontmatter hooks in plugin-loaded components don't fire.
#
# Project-local .claude/ components' hooks DO fire, so we copy there.
#
# Usage: link-plugin-components.sh [plugin-dir]
#   Without args: uses $CLAUDE_PLUGIN_ROOT (set by Claude Code)
#   With arg: processes that directory
#
# Adapted from tenzir/claude-plugins link-plugin-components.sh.
# Remove this script when upstream fixes #17688.

set -euo pipefail

project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
mkdir -p "$project_dir"
project_dir=$(cd "$project_dir" && pwd)

copied_skills=()
copied_agents=()

# Check if a file has hooks: in its YAML frontmatter
has_hooks() {
  local file="$1"
  awk '/^---$/ { if (++c == 2) exit } c == 1 && /^hooks:/ { found=1; exit } END { exit !found }' "$file"
}

# Get plugin name from plugin.json (fallback to basename)
get_plugin_name() {
  local plugin_dir="$1"
  local plugin_json="$plugin_dir/.claude-plugin/plugin.json"
  if [[ -f "$plugin_json" ]] && command -v jq &>/dev/null; then
    jq -r '.name // empty' "$plugin_json"
  else
    basename "$plugin_dir"
  fi
}

# Update name: field in frontmatter to include plugin prefix
update_name_field() {
  local file="$1"
  local original="$2"
  local prefixed="$3"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^name: ${original}$/name: ${prefixed}/" "$file"
  else
    sed -i "s/^name: ${original}$/name: ${prefixed}/" "$file"
  fi
}

# Replace $CLAUDE_PLUGIN_ROOT with absolute plugin path in hook commands
fix_plugin_root_paths() {
  local file="$1"
  local plugin_dir="$2"
  local escaped_path="${plugin_dir//\//\\/}"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/\\\$CLAUDE_PLUGIN_ROOT/${escaped_path}/g" "$file"
    sed -i '' "s/\${CLAUDE_PLUGIN_ROOT}/${escaped_path}/g" "$file"
  else
    sed -i "s/\\\$CLAUDE_PLUGIN_ROOT/${escaped_path}/g" "$file"
    sed -i "s/\${CLAUDE_PLUGIN_ROOT}/${escaped_path}/g" "$file"
  fi
}

process_plugin() {
  local plugin_dir="$1"

  if [[ ! -d "$plugin_dir" ]]; then
    echo "Warning: Plugin directory does not exist: $plugin_dir" >&2
    return 0
  fi

  plugin_dir=$(cd "$plugin_dir" && pwd)
  local plugin_name
  plugin_name=$(get_plugin_name "$plugin_dir")

  if [[ -z "$plugin_name" ]]; then
    echo "Warning: Could not determine plugin name for $plugin_dir" >&2
    return 0
  fi

  # Process skills
  local skills_dir="$plugin_dir/skills"
  if [[ -d "$skills_dir" ]]; then
    for skill_dir in "$skills_dir"/*/; do
      [[ -d "$skill_dir" ]] || continue
      local skill_file="$skill_dir/SKILL.md"
      [[ -f "$skill_file" ]] || continue

      if ! has_hooks "$skill_file"; then
        continue
      fi

      local skill_name
      skill_name=$(basename "$skill_dir")
      local prefixed_name="$plugin_name:$skill_name"
      local target="$project_dir/.claude/skills/$prefixed_name"

      if [[ -d "$target" ]]; then
        continue
      fi

      mkdir -p "$project_dir/.claude/skills"
      cp -r "$skill_dir" "$target"
      update_name_field "$target/SKILL.md" "$skill_name" "$prefixed_name"
      fix_plugin_root_paths "$target/SKILL.md" "$plugin_dir"

      copied_skills+=("$prefixed_name")
    done
  fi

  # Process agents
  local agents_dir="$plugin_dir/agents"
  if [[ -d "$agents_dir" ]]; then
    while IFS= read -r -d '' agent_file; do
      if ! has_hooks "$agent_file"; then
        continue
      fi

      local rel_path="${agent_file#$agents_dir/}"
      local original_name="${rel_path%.md}"
      original_name="${original_name//\//:}"

      local prefixed_name="$plugin_name:$original_name"
      local target="$project_dir/.claude/agents/$prefixed_name.md"

      if [[ -f "$target" ]]; then
        continue
      fi

      mkdir -p "$project_dir/.claude/agents"
      cp "$agent_file" "$target"

      local base_name
      base_name=$(basename "$agent_file" .md)
      update_name_field "$target" "$base_name" "$prefixed_name"
      fix_plugin_root_paths "$target" "$plugin_dir"

      copied_agents+=("$prefixed_name")
    done < <(find "$agents_dir" -name "*.md" -type f -print0)
  fi
}

# Structured output for SessionStart hook
output_result() {
  local display=""
  if [[ ${#copied_skills[@]} -gt 0 || ${#copied_agents[@]} -gt 0 ]]; then
    display="Copied:"
    for skill in "${copied_skills[@]}"; do
      display+=" $skill"
    done
    for agent in "${copied_agents[@]}"; do
      display+=" $agent"
    done
  else
    display="Plugin components up to date"
  fi

  # Return as hook-compatible JSON
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${display}"
  }
}
EOF
}

# Main
if [[ $# -ge 1 ]]; then
  process_plugin "$1"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
  process_plugin "$CLAUDE_PLUGIN_ROOT"
else
  echo "Error: No plugin directory specified" >&2
  exit 1
fi

output_result
