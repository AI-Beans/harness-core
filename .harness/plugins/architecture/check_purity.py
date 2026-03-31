#!/usr/bin/env python3
"""Domain Purity Checker - Law 4 Enforcement.

Scans src/domain/ for ALL .py files and verifies that imports are restricted to:
  - Python stdlib modules (allowlisted)
  - Other modules within src/domain/ only (same layer)

Any import from src/infrastructure, src/config, or third-party packages is a violation.

Exit codes:
    0 - All checks passed, domain is pure
    1 - Violation detected (external import found)

Usage:
    python3 check_purity.py [RESULT_FILE]
"""

import ast
import json
import sys
from pathlib import Path

STDLIB_ALLOWLIST = frozenset(
    {
        "typing",
        "collections",
        "collections.abc",
        "contextlib",
        "functools",
        "itertools",
        "types",
        "dataclasses",
        "enum",
        "abc",
        "re",
        "math",
        "datetime",
        "decimal",
        "copy",
        "operator",
        "string",
        "uuid",
    }
)


def _is_submodule(module: str, prefix: str) -> bool:
    return module == prefix or module.startswith(prefix + ".")


def extract_violations(filepath: Path, domain_path: Path) -> list[str]:
    """Extract import violations from a single Python file.

    A domain file may ONLY import:
      - Modules in the STDLIB_ALLOWLIST
      - Modules within src.domain.* (same layer)

    Everything else is a violation:
      - src.infrastructure.* (cross-layer)
      - src.config.* (cross-layer)
      - Any third-party package (e.g., requests, flask)
    """
    violations: list[str] = []
    try:
        content = filepath.read_text()
    except OSError:
        return violations

    try:
        tree = ast.parse(content, filename=str(filepath))
    except SyntaxError:
        return violations

    domain_dotted = "src.domain"
    forbidden_prefixes = ("src.infrastructure", "src.config", "src.presentation")

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                violations.extend(
                    _check_module(alias.name, domain_dotted, forbidden_prefixes)
                )
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                violations.extend(
                    _check_module(node.module, domain_dotted, forbidden_prefixes)
                )

    return violations


def _check_module(
    module: str,
    domain_dotted: str,
    forbidden_prefixes: tuple[str, ...],
) -> list[str]:
    """Check a single import module string against domain purity rules.

    Returns a list of violation descriptions (empty if pure).
    """
    root = module.split(".")[0]

    if root in STDLIB_ALLOWLIST:
        return []

    if root == "src":
        if _is_submodule(module, domain_dotted):
            return []
        for fp in forbidden_prefixes:
            if _is_submodule(module, fp):
                return [f"{module} (cross-layer import)"]
        if _is_submodule(module, "src"):
            return [f"{module} (import outside domain layer)"]
        return []

    return [f"{module} (external dependency: {root})"]


def check_domain_purity(domain_path: Path) -> list[tuple[Path, str]]:
    """Check domain layer for impurity violations across ALL .py files."""
    violations: list[tuple[Path, str]] = []

    if not domain_path.exists():
        return violations

    for py_file in domain_path.rglob("*.py"):
        file_violations = extract_violations(py_file, domain_path)
        for desc in file_violations:
            violations.append((py_file, desc))

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
        for filepath, desc in violations:
            try:
                rel_path = filepath.relative_to(project_root)
            except ValueError:
                rel_path = filepath
            print(f"  ✗ {rel_path}: {desc}")
        print("=" * 50)
        print("Law 4: Domain layer must import only stdlib + src.domain.*")
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
