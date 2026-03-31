#!/bin/bash
set -euo pipefail

# ============================================================
#  harness-core init.sh — One-command project bootstrap
#
#  Usage:
#    As standalone:    git clone <harness-core> && cd my-project && bash harness-core/init.sh
#    As submodule:     git submodule add <harness-core> .harness-core && bash .harness-core/init.sh
#    Inside repo:      bash init.sh
#
#  What it does:
#    1. Detects whether running inside harness-core or from a host project
#    2. Creates src/{domain,infrastructure,config}/, tests/, docs/ structure
#    3. Copies harness.yaml + AGENTS.md to project root (if not present)
#    4. Symlinks .harness/ into project root (submodule mode) or verifies it exists
#    5. Runs verify.sh to validate the setup
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect mode: are we inside harness-core itself, or in a host project?
if [ -f "$SCRIPT_DIR/.harness/verify.sh" ]; then
    HARNESS_DIR="$SCRIPT_DIR"
else
    echo "FATAL: Cannot find .harness/verify.sh relative to init.sh"
    exit 1
fi

# Determine project root
if [ "$SCRIPT_DIR" = "$(pwd)" ]; then
    # Running inside harness-core itself (standalone mode)
    PROJECT_ROOT="$SCRIPT_DIR"
    MODE="standalone"
else
    # Running from a host project (submodule mode)
    PROJECT_ROOT="$(pwd)"
    MODE="submodule"
fi

echo "============================================"
echo "  harness-core init"
echo "============================================"
echo "  Mode        : $MODE"
echo "  Project root: $PROJECT_ROOT"
echo "  Harness dir : $HARNESS_DIR"
echo ""

cd "$PROJECT_ROOT"

# ===== Create directory structure =====
echo "[init] Creating project structure..."

DIRS=(
    "src/domain"
    "src/infrastructure"
    "src/config"
    "tests"
    "docs/design-docs"
    "docs/exec-plans"
    "docs/references"
)

for d in "${DIRS[@]}"; do
    if [ ! -d "$d" ]; then
        mkdir -p "$d"
        echo "  + $d/"
    fi
done

# Create __init__.py files
INIT_FILES=(
    "src/__init__.py"
    "src/domain/__init__.py"
    "src/infrastructure/__init__.py"
    "src/config/__init__.py"
    "tests/__init__.py"
)

for f in "${INIT_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        touch "$f"
        echo "  + $f"
    fi
done

# ===== Create seed test if tests/ is empty =====
if [ -d "tests" ] && [ -z "$(find tests -name 'test_*.py' -type f 2>/dev/null)" ]; then
    cat > tests/test_init.py << 'SEED'
def test_harness_initialized():
    """Seed test — replace with your real tests."""
    assert True
SEED
    echo "  + tests/test_init.py (seed test)"
fi

# ===== Submodule mode: symlink .harness/ =====
if [ "$MODE" = "submodule" ]; then
    RELATIVE_HARNESS="$(python3 -c "import os; print(os.path.relpath('$HARNESS_DIR/.harness', '$PROJECT_ROOT'))")"

    if [ ! -e ".harness" ]; then
        ln -s "$RELATIVE_HARNESS" .harness
        echo "  + .harness -> $RELATIVE_HARNESS (symlink)"
    elif [ -L ".harness" ]; then
        echo "  ~ .harness (symlink already exists)"
    else
        echo "  ~ .harness (directory already exists, skipping symlink)"
    fi
fi

# ===== Copy template files (never overwrite) =====
copy_if_missing() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        echo "  + $dst"
    else
        echo "  ~ $dst (already exists, skipped)"
    fi
}

echo ""
echo "[init] Setting up configuration files..."

if [ "$MODE" = "submodule" ]; then
    copy_if_missing "$HARNESS_DIR/harness.yaml" "harness.yaml"
    copy_if_missing "$HARNESS_DIR/AGENTS.md" "AGENTS.md"
    copy_if_missing "$HARNESS_DIR/docs/exec-plans/progress.md" "docs/exec-plans/progress.md"
    copy_if_missing "$HARNESS_DIR/docs/exec-plans/feature_list.json" "docs/exec-plans/feature_list.json"
    copy_if_missing "$HARNESS_DIR/docs/PLANS.md" "docs/PLANS.md"
    copy_if_missing "$HARNESS_DIR/docs/METRICS.md" "docs/METRICS.md"
    copy_if_missing "$HARNESS_DIR/docs/QUALITY_SCORE.md" "docs/QUALITY_SCORE.md"
    copy_if_missing "$HARNESS_DIR/docs/ARCHITECTURE.md" "docs/ARCHITECTURE.md"
    copy_if_missing "$HARNESS_DIR/docs/design-docs/core-beliefs.md" "docs/design-docs/core-beliefs.md"
    mkdir -p "docs/exec-plans/active" "docs/exec-plans/completed"
else
    echo "  (standalone mode — files already in place)"
fi

# ===== Ensure .gitignore has harness entries =====
echo ""
echo "[init] Checking .gitignore..."

GITIGNORE_ENTRIES=(
    ".venv/"
    "__pycache__/"
    "*.pyc"
    ".mypy_cache/"
    ".ruff_cache/"
    ".pytest_cache/"
    ".coverage"
    "htmlcov/"
    "telemetry.json"
    ".telemetry_history.json"
)

if [ ! -f ".gitignore" ]; then
    printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > .gitignore
    echo "  + .gitignore (created)"
else
    ADDED=0
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qxF "$entry" .gitignore 2>/dev/null; then
            echo "$entry" >> .gitignore
            ADDED=$((ADDED + 1))
        fi
    done
    if [ "$ADDED" -gt 0 ]; then
        echo "  ~ .gitignore (added $ADDED entries)"
    else
        echo "  ~ .gitignore (already complete)"
    fi
fi

# ===== Run verification =====
echo ""
echo "[init] Running verification gate..."
echo ""

VERIFY_SCRIPT=".harness/verify.sh"
if [ "$MODE" = "submodule" ] && [ ! -e ".harness/verify.sh" ]; then
    VERIFY_SCRIPT="$HARNESS_DIR/.harness/verify.sh"
fi

export HARNESS_PROJECT_ROOT="$PROJECT_ROOT"

set +e
bash "$VERIFY_SCRIPT" "INIT" 2>&1
VERIFY_RC=$?
set -e

echo ""
if [ $VERIFY_RC -eq 0 ]; then
    echo "============================================"
    echo "  harness-core initialized successfully! ✓"
    echo "============================================"
    echo ""
    echo "  Next steps:"
    echo "    1. Write domain logic in src/domain/"
    echo "    2. Write tests in tests/"
    echo "    3. Run: bash .harness/verify.sh"
    echo ""
else
    echo "============================================"
    echo "  harness-core initialized (with warnings)"
    echo "============================================"
    echo ""
    echo "  Verification exited with code $VERIFY_RC."
    echo "  This is normal for a fresh project."
    echo "  Fix any issues, then run: bash .harness/verify.sh"
    echo ""
fi
