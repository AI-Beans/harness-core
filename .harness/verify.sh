#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASK_ID="${1:-}"
CONFIG_FILE="$PROJECT_ROOT/harness.yaml"
PLUGINS_DIR="$SCRIPT_DIR/plugins"

cd "$PROJECT_ROOT"

echo "============================================"
echo "  Microkernel Verification Dispatcher"
echo "============================================"

# ===== Validate config =====
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: harness.yaml not found at $CONFIG_FILE"
    exit 1
fi

# ===== Parse harness.yaml into associative array =====
declare -A CFG
while IFS='=' read -r k v; do
    [ -n "$k" ] && CFG["$k"]="$v"
done < <(python3 -c "
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
" "$CONFIG_FILE")

PROJECT_TYPE="${CFG[project_type]:-}"
export PROJECT_TYPE
echo "  Config   : harness.yaml"
echo "  Type     : $PROJECT_TYPE"
echo ""

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

# ===== Plugin execution function =====
run_plugin() {
    local name="$1"
    local script="$2"
    local result_file="$RESULT_DIR/${name}.json"
    local exit_file="$RESULT_DIR/${name}.exit"

    echo ""
    echo "[$name] Running $(basename "$script")..."

    set +e
    if [[ "$script" == *.py ]]; then
        python3 "$script" "$result_file" 2>&1
    else
        bash "$script" "$result_file" 2>&1
    fi
    local ec=$?
    set -e

    echo "$ec" > "$exit_file"

    if [ "$ec" -eq 0 ]; then
        echo "  ✓ $name: PASSED"
    else
        echo "  ✗ $name: FAILED (exit=$ec)"
    fi

    if [ ! -f "$result_file" ]; then
        python3 -c "
import json, sys
json.dump({'exit_code': $ec, 'error': 'no result file produced'}, sys.stdout)
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
    echo "  ⚠ Unsupported project_type: '$PROJECT_TYPE' - no plugins dispatched"
fi

# ===== Generate telemetry.json (Python json module - no heredoc) =====
echo ""
echo "Generating telemetry.json..."

python3 << 'TELEGEN'
import json
import os
import subprocess
from datetime import datetime, timezone

result_dir = os.environ["RESULT_DIR"]
task_id = os.environ.get("TASK_ID", "") or None
project_type = os.environ.get("PROJECT_TYPE", "unknown")


def read_result(name):
    path = os.path.join(result_dir, f"{name}.json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {"exit_code": -1, "error": "result not found"}


def read_exit(name):
    path = os.path.join(result_dir, f"{name}.exit")
    try:
        with open(path) as f:
            return int(f.read().strip())
    except Exception:
        return -1


def safe_count(*find_args):
    try:
        r = subprocess.run(
            ["find"] + list(find_args) + ["-type", "f"],
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


telemetry = {
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
        "src_files": safe_count("src", "-name", "*.py"),
        "test_files": safe_count("tests", "-name", "test_*.py"),
        "total_lines": safe_line_count("src", "tests"),
    },
}

with open("telemetry.json", "w") as f:
    json.dump(telemetry, f, indent=2)
    f.write("\n")

print("  ✓ telemetry.json generated")
TELEGEN

echo ""
cat telemetry.json

# ===== Update progress.txt =====
if [ -d "docs/exec-plans" ]; then
    echo ""
    echo "Updating progress.txt..."
    PROGRESS_LINE="### $(date '+%Y-%m-%d %H:%M:%S') - Task: ${TASK_ID:-none} - Dispatcher: microkernel"
    echo "$PROGRESS_LINE" >> docs/exec-plans/progress.txt
    echo "  ✓ Progress updated"
fi

# ===== Final verification gate =====
OVERALL_EXIT=0
for ef in "$RESULT_DIR"/*.exit; do
    [ -f "$ef" ] || continue
    code=$(cat "$ef")
    if [ "$code" -ne 0 ]; then
        OVERALL_EXIT=1
    fi
done

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
