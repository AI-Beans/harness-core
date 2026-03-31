#!/bin/bash
# Code Quality Verification Gate (Language-Agnostic Template)
#
# This script is a TEMPLATE. Replace placeholder regions with your stack's
# actual commands. The telemetry JSON structure and auto-commit logic
# remain constant across all languages.
#
# ==== PLACEHOLDER REGIONS ====
# Replace:
#   [YOUR_LINTER]         → ruff, eslint, golangci-lint, rustfmt, etc.
#   [YOUR_TYPE_CHECKER]   → mypy, tsc, go vet, rustc --emit=metadata, etc.
#   [YOUR_TEST_RUNNER]    → pytest, jest, go test, cargo test, etc.
#   [COVERAGE_CMD]        → pytest --cov, jest --coverage, etc.
#   [DOMAIN_CHECK]        → python3 .harness/check_purity.py, or removed
# ==== PLACEHOLDER REGIONS ====

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_ID="${1:-}"

cd "$PROJECT_ROOT"

echo "============================================"
echo "  Code Quality Verification Gate"
echo "============================================"
echo ""

# ==== LINTER SECTION ====
# Replace this placeholder with your language's linter
# Example: Linter for Python
#   LINTER_OUTPUT=$([YOUR_LINTER] check . 2>&1)
# Example: Linter for TypeScript
#   LINTER_OUTPUT=$(npx eslint src/ 2>&1)

echo "[1/N] Running [YOUR_LINTER] linter..."
LINTER_ISSUES=0
LINTER_EXIT=0
# ---- REPLACE START ----
echo "      ⚠ [YOUR_LINTER] placeholder - replace with actual linter command"
# LINTER_OUTPUT=$([YOUR_LINTER] . 2>&1)
# LINTER_EXIT=$?
# if [ $LINTER_EXIT -eq 0 ]; then
#     echo "      ✓ [YOUR_LINTER] check passed"
#     LINTER_ISSUES=0
# else
#     echo "      ✗ [YOUR_LINTER] check failed"
#     LINTER_ISSUES=1
# fi
# ---- REPLACE END ----

# ==== TYPE CHECKER SECTION ====
# Replace this placeholder with your language's type checker
# Example: Type checker for Python
#   TYPECHECK_OUTPUT=$(mypy src/ 2>&1)
# Example: Type checker for TypeScript
#   TYPECHECK_OUTPUT=$(tsc --noEmit 2>&1)

echo ""
echo "[2/N] Running [YOUR_TYPE_CHECKER] type checker..."
TYPECHECK_ISSUES=0
TYPECHECK_EXIT=0
# ---- REPLACE START ----
echo "      ⚠ [YOUR_TYPE_CHECKER] placeholder - replace with actual type checker command"
# TYPECHECK_OUTPUT=$([YOUR_TYPE_CHECKER] 2>&1)
# TYPECHECK_EXIT=$?
# if [ $TYPECHECK_EXIT -eq 0 ]; then
#     echo "      ✓ [YOUR_TYPE_CHECKER] check passed"
#     TYPECHECK_ISSUES=0
# else
#     echo "      ✗ [YOUR_TYPE_CHECKER] check failed"
#     TYPECHECK_ISSUES=1
# fi
# ---- REPLACE END ----

# ==== DOMAIN PURITY SECTION (Optional) ====
# For Python projects: uncomment and use check_purity.py
# For other languages: implement equivalent via linter plugins or remove

echo ""
echo "[3/N] Running Domain Purity Check (Law 4)..."
PURITY_ISSUES=0
PURITY_EXIT=0
# ---- REPLACE START ----
echo "      ⚠ Domain purity check requires language-specific implementation"
echo "      → See .harness/check_purity.py (Python reference plugin)"
echo "      → For other languages, use equivalent linter rules"
# For Python (uncomment if applicable):
# PURITY_OUTPUT=$(python3 .harness/check_purity.py 2>&1)
# PURITY_EXIT=$?
# if [ $PURITY_EXIT -eq 0 ]; then
#     echo "      ✓ Domain Purity check passed"
#     PURITY_ISSUES=0
# else
#     echo "      ✗ Domain Purity check FAILED"
#     PURITY_ISSUES=1
# fi
# ---- REPLACE END ----

# ==== TEST RUNNER SECTION ====
# Replace with your language's test runner with coverage
# Example: pytest for Python
#   TEST_OUTPUT=$(pytest --cov=src --cov-report=term-missing 2>&1)
# Example: jest for JavaScript/TypeScript
#   TEST_OUTPUT=$(jest --coverage 2>&1)

echo ""
echo "[4/N] Running [YOUR_TEST_RUNNER] with coverage..."
TEST_STATUS="pass"
COVERAGE=0
TESTS_PASSED=0
TESTS_FAILED=0
TEST_EXIT=0
# ---- REPLACE START ----
echo "      ⚠ [YOUR_TEST_RUNNER] placeholder - replace with actual test command"
# TEST_OUTPUT=$([YOUR_TEST_RUNNER] 2>&1)
# TEST_EXIT=$?
# COVERAGE=$(echo "$TEST_OUTPUT" | grep -E "coverage|%" | awk '{print $NF}')
# if [ $TEST_EXIT -eq 0 ]; then
#     echo "      ✓ [YOUR_TEST_RUNNER] passed"
#     TEST_STATUS="pass"
# else
#     echo "      ✗ [YOUR_TEST_RUNNER] failed"
#     TEST_STATUS="fail"
# fi
# TESTS_PASSED=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= passed)' || echo "0")
# TESTS_FAILED=$(echo "$TEST_OUTPUT" | grep -oP '\d+(?= failed)' || echo "0")
# ---- REPLACE END ----

# ==== VERIFICATION GATE ====
if [ $LINTER_EXIT -ne 0 ] || [ $TYPECHECK_EXIT -ne 0 ] || [ $PURITY_EXIT -ne 0 ] || [ $TEST_EXIT -ne 0 ]; then
    echo ""
    echo "============================================"
    echo "  Verification FAILED ✗"
    echo "============================================"
    exit 1
fi

echo ""
echo "============================================"
echo "  All checks passed! ✓"
echo "============================================"

# ==== TELEMETRY (Constant - do not modify) ====
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > telemetry.json << EOF
{
  "timestamp": "$TIMESTAMP",
  "task_id": "$TASK_ID",
  "metrics": {
    "linter": {
      "issues": $LINTER_ISSUES,
      "exit_code": $LINTER_EXIT,
      "tool": "[YOUR_LINTER]"
    },
    "type_checker": {
      "issues": $TYPECHECK_ISSUES,
      "exit_code": $TYPECHECK_EXIT,
      "tool": "[YOUR_TYPE_CHECKER]"
    },
    "domain_purity": {
      "issues": $PURITY_ISSUES,
      "exit_code": $PURITY_EXIT,
      "tool": "[DOMAIN_CHECK_TOOL]"
    },
    "coverage": {
      "percentage": ${COVERAGE:-0},
      "threshold": [COVERAGE_THRESHOLD],
      "passed": $(echo "${COVERAGE:-0} >= [COVERAGE_THRESHOLD]" | bc 2>/dev/null || echo "true")
    },
    "tests": {
      "passed": $TESTS_PASSED,
      "failed": $TESTS_FAILED,
      "status": "$TEST_STATUS",
      "tool": "[YOUR_TEST_RUNNER]"
    }
  },
  "complexity": {
    "src_files": [SRC_FILE_COUNT],
    "test_files": [TEST_FILE_COUNT],
    "total_lines": [TOTAL_LINES]
  }
}
EOF

echo ""
echo "Telemetry report:"
cat telemetry.json

# ==== PROGRESS UPDATE (Constant - do not modify) ====
echo ""
echo "Updating progress.txt..."
PROGRESS_ENTRY="### $(date '+%Y-%m-%d %H:%M:%S') - Task: ${TASK_ID:-none}\n"
PROGRESS_ENTRY+="| Metric | Value |\n"
PROGRESS_ENTRY+="|--------|-------|\n"
PROGRESS_ENTRY+="| Linter Issues | $LINTER_ISSUES |\n"
PROGRESS_ENTRY+="| Type Checker Issues | $TYPECHECK_ISSUES |\n"
PROGRESS_ENTRY+="| Domain Purity | $([ $PURITY_EXIT -eq 0 ] && echo 'pass' || echo 'FAIL') |\n"
PROGRESS_ENTRY+="| Coverage | ${COVERAGE:-0}% |\n"
PROGRESS_ENTRY+="| Tests | $TESTS_PASSED passed, $TESTS_FAILED failed |\n"
PROGRESS_ENTRY+="| Commit | telemetry.json generated |\n"
PROGRESS_ENTRY+="\n"

echo -e "$PROGRESS_ENTRY" >> docs/exec-plans/progress.txt
echo "      ✓ Progress updated"

# ==== AUTO-COMMIT (Constant - do not modify) ====
echo ""
echo "Auto-committing changes..."
git add -A
COMMIT_MSG="chore: verified code quality"
if [ -n "$TASK_ID" ]; then
    COMMIT_MSG="chore($TASK_ID): verified code quality"
fi
git commit -m "$COMMIT_MSG" || echo "Nothing to commit"
echo "      ✓ Auto-commit complete"

exit 0
