#!/usr/bin/env bash
# SessionStart hook for superpowers plugin
# shellcheck disable=SC1003

set -euo pipefail

# Determine plugin root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if legacy skills directory exists and build warning
warning_message=""
legacy_skills_dir="${HOME}/.config/superpowers/skills"
if [ -d "$legacy_skills_dir" ]; then
    warning_message="\n\n<important-reminder>IN YOUR FIRST REPLY AFTER SEEING THIS MESSAGE YOU MUST TELL THE USER:⚠️ **WARNING:** Superpowers now uses Claude Code's skills system. Custom skills in ~/.config/superpowers/skills will not be read. Move custom skills to ~/.claude/skills instead. To make this message go away, remove ~/.config/superpowers/skills</important-reminder>"
fi

# Read using-superpowers content
using_superpowers_content=$(cat "${PLUGIN_ROOT}/skills/using-superpowers/SKILL.md" 2>&1 || echo "Error reading using-superpowers skill")

# Escape outputs for JSON using pure bash
escape_for_json() {
    local input="$1"
    local output=""
    local i char
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        case "$char" in
            $'\\') output+='\\' ;;
            '"') output+='\"' ;;
            $'\n') output+='\n' ;;
            $'\r') output+='\r' ;;
            $'\t') output+='\t' ;;
            *) output+="$char" ;;
        esac
    done
    printf '%s' "$output"
}

using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")
warning_escaped=$(escape_for_json "$warning_message")

# Check for SDD checkpoint files in project temp/
checkpoint_message=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    checkpoint_dir="${CLAUDE_PROJECT_DIR}/temp"
elif [ -n "${PLUGIN_ROOT:-}" ]; then
    checkpoint_dir="${PLUGIN_ROOT}/temp"
else
    checkpoint_dir=""
fi

if [ -n "$checkpoint_dir" ] && [ -d "$checkpoint_dir" ]; then
    # Find most recent checkpoint by mtime
    latest_checkpoint=""
    for f in "${checkpoint_dir}"/sdd-checkpoint-*.json; do
        [ -f "$f" ] || continue
        if [ -z "$latest_checkpoint" ]; then
            latest_checkpoint="$f"
        else
            # Compare mtime: keep newer
            if [ "$f" -nt "$latest_checkpoint" ]; then
                latest_checkpoint="$f"
            fi
        fi
    done

    if [ -n "$latest_checkpoint" ]; then
        # Extract epic_id from filename: sdd-checkpoint-{epic_id}.json
        checkpoint_basename="${latest_checkpoint##*/}"
        checkpoint_epic_id="${checkpoint_basename#sdd-checkpoint-}"
        checkpoint_epic_id="${checkpoint_epic_id%.json}"
        checkpoint_message="\n\n<sdd-checkpoint-recovery>SDD checkpoint found for epic ${checkpoint_epic_id}. Read temp/sdd-checkpoint-${checkpoint_epic_id}.json to resume orchestration. Do NOT re-ask budget tier. See checkpoint-recovery.md for recovery logic.</sdd-checkpoint-recovery>"
    fi
fi

checkpoint_escaped=$(escape_for_json "$checkpoint_message")

# Check codex plugin installed and ready
codex_available=""
codex_install_path=""
plugins_file="${HOME}/.claude/plugins/installed_plugins.json"
if command -v jq >/dev/null 2>&1 && [ -f "$plugins_file" ]; then
    codex_install_path=$(jq -r '.plugins["codex@openai-codex"][0].installPath // empty' "$plugins_file" 2>/dev/null)
    if [ -n "$codex_install_path" ] && [ -d "$codex_install_path" ]; then
        setup_result=$(timeout 5 node "${codex_install_path}/scripts/codex-companion.mjs" setup --json 2>/dev/null || true)
        if printf '%s' "$setup_result" | jq -e '.ready == true' >/dev/null 2>&1; then
            codex_available="1"
        fi
    fi
fi

if [ -n "$codex_available" ] && [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    printf 'CODEX_REVIEW_AVAILABLE=1\n' >> "$CLAUDE_ENV_FILE"
    printf 'CODEX_INSTALL_PATH=%s\n' "$codex_install_path" >> "$CLAUDE_ENV_FILE"
fi

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'superpowers:using-superpowers' skill - your introduction to using skills. For all other skills, use the 'Skill' tool:**\n\n${using_superpowers_escaped}\n\n${warning_escaped}${checkpoint_escaped}\n</EXTREMELY_IMPORTANT>"
  }
}
EOF

exit 0
