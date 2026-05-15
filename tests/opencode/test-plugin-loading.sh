#!/usr/bin/env bash
# Test: Plugin Loading
# Verifies that the Superpowers-BD plugin loads correctly in OpenCode
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Test: Plugin Loading ==="

# Source setup to create isolated environment
source "$SCRIPT_DIR/setup.sh"

# Trap to cleanup on exit
trap cleanup_test_env EXIT

# Test 1: Verify plugin file exists and is registered
echo "Test 1: Checking plugin registration..."
if [ -L "$HOME/.config/opencode/plugins/superpowers-bd.js" ]; then
    echo "  [PASS] Plugin symlink exists in plural plugins directory"
else
    echo "  [FAIL] Plugin symlink not found at $HOME/.config/opencode/plugins/superpowers-bd.js"
    exit 1
fi

# Verify symlink target exists
if [ -f "$(readlink -f "$HOME/.config/opencode/plugins/superpowers-bd.js")" ]; then
    echo "  [PASS] Plugin symlink target exists"
else
    echo "  [FAIL] Plugin symlink target does not exist"
    exit 1
fi

if [ -f "$REPO_ROOT/.opencode/plugins/superpowers-bd.js" ]; then
    echo "  [PASS] Source plugin uses current .opencode/plugins directory"
else
    echo "  [FAIL] Source plugin missing at .opencode/plugins/superpowers-bd.js"
    exit 1
fi

# Test 2: Verify lib/skills-core.js is in place
echo "Test 2: Checking skills-core.js..."
if [ -f "$HOME/.config/opencode/superpowers-bd/lib/skills-core.js" ]; then
    echo "  [PASS] skills-core.js exists"
else
    echo "  [FAIL] skills-core.js not found"
    exit 1
fi

# Test 3: Verify skills directory is populated
echo "Test 3: Checking skills directory..."
skill_count=$(find "$HOME/.config/opencode/superpowers-bd/skills" -name "SKILL.md" | wc -l)
if [ "$skill_count" -gt 0 ]; then
    echo "  [PASS] Found $skill_count skills installed"
else
    echo "  [FAIL] No skills found in installed location"
    exit 1
fi

# Test 4: Check using-superpowers skill exists (critical for bootstrap)
echo "Test 4: Checking using-superpowers skill (required for bootstrap)..."
if [ -f "$HOME/.config/opencode/superpowers-bd/skills/using-superpowers/SKILL.md" ]; then
    echo "  [PASS] using-superpowers skill exists"
else
    echo "  [FAIL] using-superpowers skill not found (required for bootstrap)"
    exit 1
fi

# Test 5: Verify plugin JavaScript syntax (basic check)
echo "Test 5: Checking plugin JavaScript syntax..."
plugin_file="$HOME/.config/opencode/superpowers-bd/.opencode/plugins/superpowers-bd.js"
if node --check "$plugin_file" 2>/dev/null; then
    echo "  [PASS] Plugin JavaScript syntax is valid"
else
    echo "  [FAIL] Plugin has JavaScript syntax errors"
    exit 1
fi

# Test 6: Verify dependency metadata is tracked for fresh OpenCode installs
echo "Test 6: Checking OpenCode dependency metadata..."
if [ -f "$REPO_ROOT/.opencode/package.json" ] && ! git -C "$REPO_ROOT" check-ignore -q .opencode/package.json; then
    echo "  [PASS] .opencode/package.json is available for packaging"
else
    echo "  [FAIL] .opencode/package.json must exist and must not be gitignored"
    exit 1
fi

if [ -f "$HOME/.config/opencode/superpowers-bd/.opencode/package.json" ]; then
    echo "  [PASS] package metadata installed with plugin"
else
    echo "  [FAIL] package metadata missing from installed plugin fixture"
    exit 1
fi

if node -e 'const p=require(process.argv[1]); process.exit(p.dependencies && p.dependencies["@opencode-ai/plugin"] ? 0 : 1)' "$REPO_ROOT/.opencode/package.json"; then
    echo "  [PASS] @opencode-ai/plugin dependency declared"
else
    echo "  [FAIL] @opencode-ai/plugin dependency missing"
    exit 1
fi

if node -e 'const p=require(process.argv[1]); process.exit(p.type === "module" ? 0 : 1)' "$REPO_ROOT/.opencode/package.json"; then
    echo "  [PASS] OpenCode package marked as ESM"
else
    echo "  [FAIL] .opencode/package.json must set type=module for ESM plugins"
    exit 1
fi

# Test 7: Verify personal test skill was created
echo "Test 7: Checking test fixtures..."
if [ -f "$HOME/.config/opencode/skills/personal-test/SKILL.md" ]; then
    echo "  [PASS] Personal test skill fixture created"
else
    echo "  [FAIL] Personal test skill fixture not found"
    exit 1
fi

echo ""
echo "=== All plugin loading tests passed ==="
