#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
TASK_ID="${1:-}"
CONFIG_FILE="$PROJECT_ROOT/harness.yaml"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

cd "$PROJECT_ROOT"

echo "============================================"
echo "  Microkernel Verification Dispatcher"
echo "============================================"

# ===== Pre-flight: python3 must exist =====
if ! command -v python3 &>/dev/null; then
    echo "FATAL: python3 not found on PATH — cannot parse config or run plugins"
    exit 1
fi

# ===== Validate config =====
if [ ! -f "$CONFIG_FILE" ]; then
    echo "FATAL: harness.yaml not found at $CONFIG_FILE"
    exit 1
fi

# ===== Parse harness.yaml into associative array =====
declare -A CFG
PARSE_OUTPUT=""
PARSE_OUTPUT=$(python3 -c "
import sys

def parse_yaml(path):
    result = {}
    in_modules = False
    current_module = None

    with open(path) as f:
        for raw in f:
            line = raw.rstrip('\n')
            stripped = line.strip()
            if not stripped or stripped.startswith('#'):
                continue

            indent = len(raw) - len(raw.lstrip())
            key, _, val = stripped.partition(':')
            key = key.strip()
            val = val.strip()

            # Strip inline comments (DF-1)
            if val and '#' in val:
                val = val.split('#')[0].strip()

            if indent == 0:
                in_modules = (key == 'modules')
                current_module = None
                if val:
                    result[key] = val
            elif indent == 2 and in_modules:
                current_module = key
                if val:
                    result[f'modules__{key}'] = val
            elif indent >= 4 and current_module:
                result[f'modules__{current_module}__{key}'] = val

    return result

cfg = parse_yaml(sys.argv[1])
for k, v in cfg.items():
    print(f'{k}={v}')
" "$CONFIG_FILE" 2>&1) || {
    echo "FATAL: Failed to parse harness.yaml — python3 inline parser exited non-zero"
    echo "$PARSE_OUTPUT"
    exit 1
}

while IFS='=' read -r k v; do
    [ -n "$k" ] && CFG["$k"]="$v"
done <<< "$PARSE_OUTPUT"

# ===== Validate parsed config (CVE-H1 fix) =====
if [ ${#CFG[@]} -eq 0 ]; then
    echo "FATAL: harness.yaml parsed but produced zero config entries"
    exit 1
fi

PROJECT_TYPE="${CFG[project_type]:-}"
if [ -z "$PROJECT_TYPE" ]; then
    echo "FATAL: project_type not found in harness.yaml"
    exit 1
fi

export PROJECT_TYPE
echo "  Config   : harness.yaml"
echo "  Type     : $PROJECT_TYPE"
echo "  Root     : $PROJECT_ROOT"
echo ""

# ===== Export configurable values for plugins (DF-3 / DF-5) =====
export HARNESS_COVERAGE_THRESHOLD="${CFG[modules__tests__coverage_threshold]:-80}"
export HARNESS_DOMAIN_PATH="${CFG[paths__domain]:-src/domain}"
export HARNESS_SRC_PATHS="${CFG[paths__src]:-src}"
export HARNESS_TEST_PATHS="${CFG[paths__tests]:-tests}"

PLUGIN_TIMEOUT="${CFG[plugin_timeout]:-300}"

# ===== Bootstrap environment =====
if [ "$PROJECT_TYPE" = "python" ]; then
    echo "[Env] Bootstrapping Python environment..."
    set +e
    bash "$PLUGINS_DIR/python/setup_env.sh" 2>&1
    ENV_RC=$?
    set -e
    if [ $ENV_RC -ne 0 ]; then
        echo ""
        echo "============================================"
        echo "  Environment bootstrap FAILED ✗"
        echo "  Cannot proceed without .venv"
        echo "============================================"
        exit 1
    fi
fi

# ===== Setup result directory =====
RESULT_DIR=$(mktemp -d)
trap 'rm -rf "$RESULT_DIR"' EXIT
export RESULT_DIR TASK_ID

PLUGINS_RAN=0

# ===== Plugin execution function (with timeout — DF-4) =====
run_plugin() {
    local name="$1"
    local script="$2"
    local result_file="$RESULT_DIR/${name}.json"
    local exit_file="$RESULT_DIR/${name}.exit"

    echo ""
    echo "[$name] Running $(basename "$script")..."

    set +e
    if [[ "$script" == *.py ]]; then
        timeout "$PLUGIN_TIMEOUT" python3 "$script" "$result_file" 2>&1
    else
        timeout "$PLUGIN_TIMEOUT" bash "$script" "$result_file" 2>&1
    fi
    local ec=$?
    set -e

    if [ "$ec" -eq 124 ]; then
        echo "  ✗ $name: TIMEOUT (exceeded ${PLUGIN_TIMEOUT}s)"
    fi

    echo "$ec" > "$exit_file"
    PLUGINS_RAN=$((PLUGINS_RAN + 1))

    if [ "$ec" -eq 0 ]; then
        echo "  ✓ $name: PASSED"
    else
        echo "  ✗ $name: FAILED (exit=$ec)"
    fi

    if [ ! -f "$result_file" ]; then
        PLUGIN_EC="$ec" python3 -c "
import json, os, sys
ec = int(os.environ.get('PLUGIN_EC', '1'))
json.dump({'exit_code': ec, 'error': 'no result file produced'}, sys.stdout)
" > "$result_file"
    fi
}

# ===== Dispatch plugins based on project_type =====
if [ "$PROJECT_TYPE" = "python" ]; then

    if [ "${CFG[modules__linter__enabled]:-false}" = "true" ]; then
        run_plugin "linter" "$PLUGINS_DIR/python/run_linter.sh"
    fi

    if [ "${CFG[modules__type_checker__enabled]:-false}" = "true" ]; then
        run_plugin "type_checker" "$PLUGINS_DIR/python/run_typecheck.sh"
    fi

    if [ "${CFG[modules__domain_purity__enabled]:-false}" = "true" ]; then
        run_plugin "domain_purity" "$PLUGINS_DIR/architecture/check_purity.py"
    fi

    if [ "${CFG[modules__tests__enabled]:-false}" = "true" ]; then
        run_plugin "tests" "$PLUGINS_DIR/python/run_tests.sh"
    fi
else
    echo "  FATAL: Unsupported project_type: '$PROJECT_TYPE'"
    exit 1
fi

# ===== Guard: at least one plugin must have run (CVE-H1 fix) =====
if [ "$PLUGINS_RAN" -eq 0 ]; then
    echo "FATAL: No plugins were dispatched — all modules disabled in harness.yaml?"
    exit 1
fi

# ===== Generate telemetry.json (Python json module - no heredoc) =====
echo ""
echo "Generating telemetry.json..."

TELEMETRY_HISTORY="${PROJECT_ROOT}/.telemetry_history.json"
export TELEMETRY_HISTORY

python3 << 'TELEGEN'
import json
import os
import subprocess
from datetime import datetime, timezone

result_dir = os.environ["RESULT_DIR"]
task_id = os.environ.get("TASK_ID", "") or None
project_type = os.environ.get("PROJECT_TYPE", "unknown")
history_path = os.environ.get("TELEMETRY_HISTORY", ".telemetry_history.json")
src_paths = os.environ.get("HARNESS_SRC_PATHS", "src")
test_paths = os.environ.get("HARNESS_TEST_PATHS", "tests")


def read_result(name):
    path = os.path.join(result_dir, f"{name}.json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {"exit_code": -1, "error": "result not found"}


def safe_count(directory, pattern):
    try:
        r = subprocess.run(
            ["find", directory, "-name", pattern, "-type", "f"],
            capture_output=True, text=True, timeout=10
        )
        lines = [l for l in r.stdout.strip().split("\n") if l]
        return len(lines)
    except Exception:
        return 0


def safe_line_count(*dirs):
    total = 0
    for d in dirs:
        try:
            r = subprocess.run(
                ["find", d, "-name", "*.py", "-type", "f"],
                capture_output=True, text=True, timeout=10
            )
            files = [l for l in r.stdout.strip().split("\n") if l]
            for fp in files:
                try:
                    with open(fp) as fh:
                        total += sum(1 for _ in fh)
                except Exception:
                    pass
        except Exception:
            pass
    return total


entry = {
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "task_id": task_id,
    "project_type": project_type,
    "metrics": {
        "linter": read_result("linter"),
        "type_checker": read_result("type_checker"),
        "domain_purity": read_result("domain_purity"),
        "tests": read_result("tests"),
    },
    "complexity": {
        "src_files": safe_count(src_paths, "*.py"),
        "test_files": safe_count(test_paths, "test_*.py"),
        "total_lines": safe_line_count(src_paths, test_paths),
    },
}

with open("telemetry.json", "w") as f:
    json.dump(entry, f, indent=2)
    f.write("\n")

# Append to history (AF-2 fix)
history = []
try:
    with open(history_path) as f:
        history = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

history.append(entry)

MAX_HISTORY = 100
if len(history) > MAX_HISTORY:
    history = history[-MAX_HISTORY:]

with open(history_path, "w") as f:
    json.dump(history, f, indent=2)
    f.write("\n")

print("  ✓ telemetry.json generated")
print(f"  ✓ history appended ({len(history)} entries in {history_path})")
TELEGEN

echo ""
cat telemetry.json

# ===== Final verification gate =====
OVERALL_EXIT=0
for ef in "$RESULT_DIR"/*.exit; do
    [ -f "$ef" ] || continue
    code=$(cat "$ef")
    if [ "$code" -ne 0 ]; then
        OVERALL_EXIT=1
    fi
done

# ===== Update progress log =====
PROGRESS_FILE="docs/exec-plans/progress.md"
if [ -d "docs/exec-plans" ]; then
    echo ""
    PASS_FAIL="PASS"
    [ "$OVERALL_EXIT" -ne 0 ] && PASS_FAIL="FAIL"
    PROGRESS_LINE="### $(date '+%Y-%m-%d %H:%M:%S') — Task: ${TASK_ID:-none} — ${PASS_FAIL}"
    echo "" >> "$PROGRESS_FILE"
    echo "$PROGRESS_LINE" >> "$PROGRESS_FILE"
fi

echo ""
if [ "$OVERALL_EXIT" -eq 0 ]; then
    echo "============================================"
    echo "  All checks passed! ✓"
    echo "============================================"

    echo ""
    echo "[Git] Running auto-commit..."
    set +e
    bash "$PLUGINS_DIR/git/auto_commit.sh" 2>&1
    set -e
else
    echo "============================================"
    echo "  Verification FAILED ✗"
    echo "============================================"
fi

exit $OVERALL_EXIT
