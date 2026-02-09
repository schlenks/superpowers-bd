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

# Compute md5 hash of a single file (portable: macOS md5 -q / Linux md5sum)
hash_file() {
  local file="$1"
  if md5 -q /dev/null &>/dev/null; then
    md5 -q "$file"
  else
    md5sum "$file" | cut -d' ' -f1
  fi
}

# Compute md5 hash of a skill directory's contents.
# Uses length-framed records (path<TAB>byte_count<NL>content) so record boundaries
# are unambiguous regardless of file content. Assumes filenames contain no tabs or
# newlines (valid for plugin skill trees).
hash_skill_dir() {
  local dir="$1"
  if md5 -q /dev/null &>/dev/null; then
    (cd "$dir" && LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sh -c \
      'for f; do sz=$(wc -c < "$f"); printf "%s\t%d\n" "$f" "$sz"; cat "$f"; done' _ | md5 -q)
  else
    (cd "$dir" && LC_ALL=C find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sh -c \
      'for f; do sz=$(wc -c < "$f"); printf "%s\t%d\n" "$f" "$sz"; cat "$f"; done' _ | md5sum | cut -d' ' -f1)
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

      local source_hash
      source_hash=$(hash_skill_dir "$skill_dir")
      local hash_file="$target/.source-hash"
      if [[ -d "$target" && -f "$hash_file" ]]; then
        local stored_hash
        stored_hash=$(cat "$hash_file")
        if [[ "$source_hash" == "$stored_hash" ]]; then
          continue  # Source unchanged, skip
        fi
        rm -rf "$target"  # Remove stale copy to avoid cp -r nesting
      elif [[ -d "$target" ]]; then
        # Legacy target from before hash tracking — treat as stale
        rm -rf "$target"
      fi

      mkdir -p "$project_dir/.claude/skills"
      cp -r "$skill_dir" "$target"
      update_name_field "$target/SKILL.md" "$skill_name" "$prefixed_name"
      fix_plugin_root_paths "$target/SKILL.md" "$plugin_dir"
      mkdir -p "$target"
      echo "$source_hash" > "$hash_file"

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

      local source_hash
      source_hash=$(hash_file "$agent_file")
      local hash_sidecar="${target}.source-hash"
      if [[ -f "$target" && -f "$hash_sidecar" ]]; then
        local stored_hash
        stored_hash=$(cat "$hash_sidecar")
        if [[ "$source_hash" == "$stored_hash" ]]; then
          continue  # Source unchanged, skip
        fi
        # Source changed — will re-copy below
      fi
      # Note: if target exists but hash_sidecar doesn't (legacy install), fall through
      # to re-copy. For agents (single files), cp overwrites safely. Hash file
      # gets created after copy, completing the migration.

      mkdir -p "$project_dir/.claude/agents"
      cp "$agent_file" "$target"

      local base_name
      base_name=$(basename "$agent_file" .md)
      update_name_field "$target" "$base_name" "$prefixed_name"
      fix_plugin_root_paths "$target" "$plugin_dir"
      echo "$source_hash" > "$hash_sidecar"

      copied_agents+=("$prefixed_name")
    done < <(find "$agents_dir" -name "*.md" -type f -print0)
  fi

  # Prune orphaned agent copies
  local agents_target_dir="$project_dir/.claude/agents"
  if [[ -d "$agents_target_dir" ]]; then
    for target_file in "$agents_target_dir/${plugin_name}:"*.md; do
      [[ -f "$target_file" ]] || continue
      local target_basename
      target_basename=$(basename "$target_file" .md)
      local original_name="${target_basename#${plugin_name}:}"
      local original_path="${original_name//:/\/}"
      local source_file="$agents_dir/${original_path}.md"
      if [[ ! -f "$source_file" ]] || ! has_hooks "$source_file"; then
        rm -f "$target_file" "${target_file}.source-hash"
      fi
    done
  fi

  # Prune orphaned skill copies
  local skills_target_dir="$project_dir/.claude/skills"
  if [[ -d "$skills_target_dir" ]]; then
    for target_dir in "$skills_target_dir/${plugin_name}:"*/; do
      [[ -d "$target_dir" ]] || continue
      local target_basename
      target_basename=$(basename "$target_dir")
      local original_name="${target_basename#${plugin_name}:}"
      local original_path="${original_name//:/\/}"
      local source_dir="$skills_dir/$original_path"
      local source_file="$source_dir/SKILL.md"
      if [[ ! -f "$source_file" ]] || ! has_hooks "$source_file"; then
        rm -rf "$target_dir"
      fi
    done
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
