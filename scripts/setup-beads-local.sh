#!/usr/bin/env bash
# setup-beads-local.sh
# Sets up beads for local-only use (not committed to repo)
# Includes worktree support for seamless multi-worktree workflows

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if we're in a git repo
git rev-parse --is-inside-work-tree &>/dev/null || error "Not inside a git repository"

# Get repo root and cd there (fixes: bd init from subdirectory)
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Step 1: Install beads if not present
if ! command -v bd &>/dev/null; then
  info "Installing beads..."
  if command -v brew &>/dev/null; then
    brew install beads
  elif command -v npm &>/dev/null; then
    npm install -g @beads/bd
  elif command -v go &>/dev/null; then
    go install github.com/steveyegge/beads/cmd/bd@latest
    # go install puts binary in GOBIN or GOPATH/bin - warn if not in PATH
    if ! command -v bd &>/dev/null; then
      warn "beads installed via go but 'bd' not found in PATH"
      warn "Add \$(go env GOPATH)/bin to your PATH, then re-run this script"
      exit 1
    fi
  else
    error "No package manager found. Install beads manually: https://github.com/steveyegge/beads"
  fi
else
  info "beads already installed: $(bd --version 2>/dev/null || echo 'unknown version')"
fi

# Step 2: Initialize beads in stealth mode (now guaranteed at repo root)
if [[ -d ".beads" ]]; then
  info ".beads directory already exists, skipping init"
else
  info "Initializing beads in stealth mode..."
  bd init --stealth
fi

# Step 3: Add worktree support to shell config
SHELL_RC=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [[ -n "$SHELL_RC" ]]; then
  # More specific check: look for the function definition, not just the name
  if grep -q "^bdwtauto()" "$SHELL_RC" 2>/dev/null; then
    info "Worktree support already in $SHELL_RC"
  else
    info "Adding worktree support to $SHELL_RC..."
    cat >> "$SHELL_RC" << 'BEADS_WORKTREE_EOF'

# ------------------------------------------------------------------------------
# Beads: worktree-aware local exclude (from superpowers)
# Ensures .beads/ is ignored in each worktree's local git exclude
# ------------------------------------------------------------------------------

bdwt() {
  local mode="normal"
  [[ "${1:-}" == "--quiet" ]] && mode="quiet"
  [[ "${1:-}" == "--changed" ]] && mode="changed"

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    [[ "$mode" == "quiet" ]] || echo "bdwt: not inside a git repository"
    return 1
  }

  local exclude_file
  exclude_file="$(git rev-parse --git-path info/exclude 2>/dev/null)" || {
    [[ "$mode" == "quiet" ]] || echo "bdwt: unable to resolve git info/exclude path"
    return 1
  }

  mkdir -p -- "$(dirname "$exclude_file")"
  touch -- "$exclude_file"

  if command grep -qxF ".beads/" "$exclude_file" 2>/dev/null; then
    [[ "$mode" == "normal" ]] && echo "bdwt: .beads/ already present in $exclude_file"
    return 0
  fi

  echo ".beads/" >> "$exclude_file"
  [[ "$mode" != "quiet" ]] && echo "bdwt: added .beads/ to $exclude_file"
  return 0
}

# Global variable for caching last repo root (works in both bash and zsh)
BDWT_AUTO_LAST_ROOT=""

bdwtauto() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  [[ "$repo_root" == "$BDWT_AUTO_LAST_ROOT" ]] && return 0
  BDWT_AUTO_LAST_ROOT="$repo_root"
  [[ -d "$repo_root/.beads" ]] || return 0
  bdwt --changed
}

if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd bdwtauto
elif [[ -n "${BASH_VERSION:-}" ]]; then
  # Handle PROMPT_COMMAND as array (bash 5+) or string (bash 3/4)
  if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
    PROMPT_COMMAND+=("bdwtauto")
  else
    PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }bdwtauto"
  fi
fi

# Run once for initial directory
bdwtauto
BEADS_WORKTREE_EOF
    info "Worktree support added to $SHELL_RC"
  fi
else
  warn "Could not find .zshrc or .bashrc - add worktree functions manually"
fi

echo ""
info "Setup complete!"
echo ""
echo "What was configured:"
echo "  1. beads CLI installed (if needed)"
echo "  2. beads initialized in stealth mode (.beads/ stays local)"
if [[ -n "$SHELL_RC" ]]; then
  echo "  3. Worktree support added to shell (auto-excludes .beads/ in worktrees)"
  echo ""
  echo "Next steps:"
  echo "  - Restart your shell or run: source $SHELL_RC"
else
  echo "  3. Worktree support NOT added (no .zshrc or .bashrc found)"
  echo ""
  echo "Next steps:"
  echo "  - Manually add worktree functions from: https://github.com/schlenks/superpowers#local-only-beads-setup"
fi
echo "  - Run 'bd ready' to see available tasks"
echo "  - Run 'bd create --title=\"My task\"' to create issues"
echo ""
