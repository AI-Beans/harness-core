#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESULT_FILE="${1:-}"

cd "$PROJECT_ROOT"

if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

echo "[TypeChecker] Running mypy on src/..."

OUTPUT_FILE=$(mktemp /tmp/mypy_output.XXXXXX)
trap "rm -f '$OUTPUT_FILE'" RETURN

set +e
mypy src/ > "$OUTPUT_FILE" 2>&1
EXIT_CODE=$?
set -e

ISSUES=0

if [ $EXIT_CODE -eq 0 ]; then
    echo "  ✓ MyPy check passed"
else
    echo "  ✗ MyPy check failed"
    cat "$OUTPUT_FILE"
    ISSUES=$(grep -cE 'error:' "$OUTPUT_FILE" 2>/dev/null || true)
    if [ -z "$ISSUES" ]; then
        ISSUES=0
    fi
fi

if [ -n "$RESULT_FILE" ]; then
    EXIT_CODE=$EXIT_CODE ISSUES=$ISSUES python3 -c "
import json, os, sys
data = {
    'exit_code': int(os.environ.get('EXIT_CODE', '1')),
    'issues': int(os.environ.get('ISSUES', '0')),
    'tool': 'mypy'
}
json.dump(data, sys.stdout)
" > "$RESULT_FILE"
fi

exit $EXIT_CODE
