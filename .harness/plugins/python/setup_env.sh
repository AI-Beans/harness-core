#!/bin/bash
set -euo pipefail

PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
cd "$PROJECT_ROOT"

TOOLCHAIN_REQ=".harness/requirements-toolchain.txt"

if [ -d ".venv" ]; then
    echo "[Env] .venv exists — verifying activation..."
    set +e
    source .venv/bin/activate 2>/dev/null
    ACTIVATE_RC=$?
    set -e
    if [ $ACTIVATE_RC -ne 0 ]; then
        echo "[Env] ✗ .venv exists but activation failed — removing and recreating"
        rm -rf .venv
    else
        PYTHON_PATH=$(command -v python3 2>/dev/null || true)
        if [[ "$PYTHON_PATH" == *".venv"* ]]; then
            echo "[Env] ✓ .venv activated ($PYTHON_PATH)"
            exit 0
        else
            echo "[Env] ✗ .venv activated but python3 not from venv — recreating"
            rm -rf .venv
        fi
    fi
fi

echo "[Env] .venv not found — creating virtual environment..."

if command -v uv &>/dev/null; then
    echo "[Env] Using uv ($(uv --version 2>/dev/null || echo 'unknown'))"
    uv venv .venv
    source .venv/bin/activate
    if [ -f "pyproject.toml" ]; then
        echo "[Env] Syncing dependencies from pyproject.toml..."
        uv sync 2>/dev/null || true
    fi
    echo "[Env] Installing pinned toolchain..."
    if [ -f "$TOOLCHAIN_REQ" ]; then
        uv pip install -r "$TOOLCHAIN_REQ"
    else
        uv pip install "ruff>=0.9,<1" "mypy>=1.15,<2" "pytest>=8,<9" "pytest-cov>=6,<7"
    fi
else
    echo "[Env] uv not found — falling back to python3 -m venv"
    python3 -m venv .venv
    source .venv/bin/activate
    echo "[Env] Installing pinned toolchain..."
    if [ -f "$TOOLCHAIN_REQ" ]; then
        pip install --quiet -r "$TOOLCHAIN_REQ"
    else
        pip install --quiet "ruff>=0.9,<1" "mypy>=1.15,<2" "pytest>=8,<9" "pytest-cov>=6,<7"
    fi
fi

PYTHON_PATH=$(command -v python3)
if [[ "$PYTHON_PATH" == *".venv"* ]]; then
    echo "[Env] ✓ Virtual environment ready ($PYTHON_PATH)"
else
    echo "[Env] ✗ FATAL: python3 not from .venv after bootstrap — aborting"
    exit 1
fi
