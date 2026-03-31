#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RESULT_FILE="${1:-}"

cd "$PROJECT_ROOT"

if [ -d ".venv" ]; then
    source .venv/bin/activate
fi

echo "[Tests] Running pytest with coverage..."

OUTPUT_FILE=$(mktemp /tmp/pytest_output.XXXXXX)
trap "rm -f '$OUTPUT_FILE'" RETURN

set +e
pytest --cov=src --cov-report=term-missing > "$OUTPUT_FILE" 2>&1
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo "  ✓ Pytest passed"
else
    echo "  ✗ Pytest failed"
fi

cat "$OUTPUT_FILE"

if [ -n "$RESULT_FILE" ]; then
    EXIT_CODE=$EXIT_CODE python3 -c "
import json, os, re, sys

output_file = sys.argv[1]
try:
    with open(output_file) as f:
        output = f.read()
except Exception:
    output = ''

exit_code = int(os.environ.get('EXIT_CODE', '1'))

coverage = 0
for line in output.split('\n'):
    stripped = line.strip()
    if stripped.startswith('TOTAL'):
        parts = line.split()
        for p in reversed(parts):
            p_clean = p.rstrip('%')
            try:
                coverage = int(p_clean)
                break
            except ValueError:
                continue
        break

passed = 0
failed = 0
for match in re.finditer(r'(\d+)\s+passed', output):
    passed = int(match.group(1))
for match in re.finditer(r'(\d+)\s+failed', output):
    failed = int(match.group(1))

status = 'pass' if exit_code == 0 else 'fail'
threshold = 80

data = {
    'exit_code': exit_code,
    'tool': 'pytest',
    'passed': passed,
    'failed': failed,
    'status': status,
    'coverage': {
        'percentage': coverage,
        'threshold': threshold,
        'passed': coverage >= threshold
    }
}
json.dump(data, sys.stdout)
" "$OUTPUT_FILE" > "$RESULT_FILE"
fi

exit $EXIT_CODE
