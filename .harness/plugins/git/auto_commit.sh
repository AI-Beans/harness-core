#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

TELEMETRY_FILE="telemetry.json"

if [ ! -f "$TELEMETRY_FILE" ]; then
    echo "[Git] ✗ telemetry.json not found — nothing to commit"
    exit 1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TASK_ID=$(python3 -c "
import json, sys
with open('$TELEMETRY_FILE') as f:
    d = json.load(f)
print(d.get('task_id') or 'none')
")

METRICS=$(python3 -c "
import json, sys
with open('$TELEMETRY_FILE') as f:
    d = json.load(f)
m = d.get('metrics', {})
total = len(m)
passed = sum(1 for v in m.values() if isinstance(v, dict) and v.get('exit_code', -1) == 0)
ptype = d.get('project_type', 'unknown')
print(f'{passed}/{total} Pass [{ptype}/Microkernel]')
")

COMMIT_MSG="chore(${TASK_ID}): Harness Verified: ${METRICS} @ ${TIMESTAMP}"

git add -A

set +e
git diff --cached --quiet
DIFF_RC=$?
set -e

if [ $DIFF_RC -eq 0 ]; then
    echo "[Git] Nothing to commit"
    exit 0
fi

git commit -m "$COMMIT_MSG"
echo "[Git] ✓ Auto-commit: $COMMIT_MSG"
