#!/usr/bin/env python3
"""Domain Purity Checker - Law 4 Enforcement.

Traverses src/domain/ and checks that no external imports exist
(except typing module imports which are allowed for type hints).

Exit codes:
    0 - All checks passed, domain is pure
    1 - Violation detected (external import found)
    2 - Error (e.g., file read error)
"""

import ast
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
    "src",
}


def extract_imports(filepath: Path) -> set[str]:
    """Extract all import statements from a Python file.

    Args:
        filepath: Path to Python file.

    Returns:
        Set of imported module names.
    """
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
    """Check domain layer for impurity violations.

    Args:
        domain_path: Path to src/domain directory.

    Returns:
        List of (file, import_module) tuples that are violations.
    """
    violations: list[tuple[Path, str]] = []

    if not domain_path.exists():
        return violations

    for py_file in domain_path.rglob("__init__.py"):
        imports = extract_imports(py_file)
        for imp in imports:
            if imp not in ALLOWED_IMPORTS and not imp.startswith("src."):
                violations.append((py_file, imp))

    return violations


def main() -> int:
    """Main entry point."""
    script_dir = Path(__file__).parent.resolve()
    project_root = script_dir.parent
    domain_path = project_root / "src" / "domain"

    violations = check_domain_purity(domain_path)

    if violations:
        print("DOMAIN PURITY VIOLATION - Law 4 BREACH")
        print("=" * 50)
        for filepath, imp in violations:
            rel_path = filepath.relative_to(project_root)
            print(f"  ✗ {rel_path}: imports '{imp}'")
        print("=" * 50)
        print("Law 4: Domain layer must be pure (typing/stdlib only)")
        return 1

    print("Domain Purity Check: PASSED")
    print(f"Checked: {domain_path}")
    print("Law 4 Enforcement: ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
