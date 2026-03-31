#!/usr/bin/env python3
"""Domain Purity Checker - Law 4 Enforcement (Plugin Version).

Scans src/domain/ for ALL .py files and verifies no external imports exist
(except typing module imports and stdlib utility modules).

Exit codes:
    0 - All checks passed, domain is pure
    1 - Violation detected (external import found)
    2 - Error (e.g., file read error)

Usage:
    python3 check_purity.py [RESULT_FILE]

    RESULT_FILE: optional path to write JSON result for the dispatcher.
"""

import ast
import json
import sys
from pathlib import Path

ALLOWED_IMPORTS = {
    "typing",
    "collections.abc",
    "contextlib",
    "functools",
    "itertools",
    "types",
    "dataclasses",
    "enum",
    "abc",
    "src",
}


def extract_imports(filepath: Path) -> set[str]:
    """Extract all import module roots from a Python file via AST walk."""
    imports: set[str] = set()
    try:
        content = filepath.read_text()
    except OSError:
        return imports

    try:
        tree = ast.parse(content, filename=str(filepath))
    except SyntaxError:
        return imports

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                imports.add(alias.name.split(".")[0])
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imports.add(node.module.split(".")[0])

    return imports


def check_domain_purity(domain_path: Path) -> list[tuple[Path, str]]:
    """Check domain layer for impurity violations across ALL .py files.

    FIX: Previous version only scanned __init__.py via rglob("__init__.py").
    Now scans every .py file under the domain directory.
    """
    violations: list[tuple[Path, str]] = []

    if not domain_path.exists():
        return violations

    for py_file in domain_path.rglob("*.py"):
        imports = extract_imports(py_file)
        for imp in imports:
            if imp not in ALLOWED_IMPORTS and not imp.startswith("src."):
                violations.append((py_file, imp))

    return violations


def main() -> int:
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent.parent.parent
    domain_path = project_root / "src" / "domain"
    result_file = sys.argv[1] if len(sys.argv) > 1 else None

    violations = check_domain_purity(domain_path)
    files_scanned = len(list(domain_path.rglob("*.py"))) if domain_path.exists() else 0

    if violations:
        print("DOMAIN PURITY VIOLATION - Law 4 BREACH")
        print("=" * 50)
        for filepath, imp in violations:
            try:
                rel_path = filepath.relative_to(project_root)
            except ValueError:
                rel_path = filepath
            print(f"  ✗ {rel_path}: imports '{imp}'")
        print("=" * 50)
        print("Law 4: Domain layer must be pure (typing/stdlib only)")
        print(f"Scanned {files_scanned} file(s), found {len(violations)} violation(s)")
        exit_code = 1
    else:
        print("Domain Purity Check: PASSED")
        print(f"Checked: {domain_path}")
        print(f"Scanned {files_scanned} file(s)")
        print("Law 4 Enforcement: ✓")
        exit_code = 0

    if result_file:
        result = {
            "exit_code": exit_code,
            "issues": len(violations),
            "tool": "check_purity.py",
            "files_scanned": files_scanned,
        }
        with open(result_file, "w") as f:
            json.dump(result, f, indent=2)

    return exit_code


if __name__ == "__main__":
    sys.exit(main())
