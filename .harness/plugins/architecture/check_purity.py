#!/usr/bin/env python3
"""Domain Purity Checker - Law 4 Enforcement.

Scans the domain directory for ALL .py files and verifies that imports are
restricted to:
  - Python stdlib modules (allowlisted)
  - Other modules within the domain layer only (same layer)

Violations detected:
  - Static imports from infrastructure/config/third-party (ast.Import / ast.ImportFrom)
  - Relative imports that escape the domain boundary (from .. import X)
  - Dynamic imports via __import__(), exec(), eval(), importlib.import_module()

Exit codes:
    0 - All checks passed, domain is pure
    1 - Violation detected

Usage:
    python3 check_purity.py [RESULT_FILE]

Environment variables:
    HARNESS_DOMAIN_PATH  - Relative path to domain dir (default: src/domain)
"""

import ast
import json
import os
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

DANGEROUS_BUILTINS = frozenset({"__import__", "exec", "eval", "compile"})

DANGEROUS_ATTR_CALLS = frozenset({"import_module", "find_module", "find_spec"})


def _is_submodule(module: str, prefix: str) -> bool:
    return module == prefix or module.startswith(prefix + ".")


def _resolve_relative_target(
    filepath: Path,
    domain_path: Path,
    level: int,
) -> Path | None:
    """Resolve the directory a relative import points to based on level.

    In Python's import system:
      level=1 (from . import X)   → current package = filepath.parent
      level=2 (from .. import X)  → parent package  = filepath.parent.parent
      level=N                     → go up (N-1) dirs from filepath.parent
    """
    base = filepath.parent
    for _ in range(level - 1):
        base = base.parent
    try:
        base.relative_to(domain_path)
        return base
    except ValueError:
        return None


def extract_violations(
    filepath: Path,
    domain_path: Path,
    project_root: Path,
) -> list[str]:
    """Extract import violations from a single Python file."""
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
            if node.level and node.level > 0:
                # Relative import — check if it escapes domain boundary
                violations.extend(
                    _check_relative_import(node, filepath, domain_path)
                )
            elif node.module:
                violations.extend(
                    _check_module(node.module, domain_dotted, forbidden_prefixes)
                )

        elif isinstance(node, ast.Call):
            violations.extend(_check_dangerous_call(node))

    return violations


def _check_module(
    module: str,
    domain_dotted: str,
    forbidden_prefixes: tuple[str, ...],
) -> list[str]:
    """Check a single import module string against domain purity rules."""
    root = module.split(".")[0]

    if root in STDLIB_ALLOWLIST:
        return []

    if root == "src":
        if _is_submodule(module, domain_dotted):
            return []
        for fp in forbidden_prefixes:
            if _is_submodule(module, fp):
                return [
                    f"{module} (cross-layer import). "
                    f"FIX: Move this dependency behind an interface in src/domain/ "
                    f"and inject the implementation from src/infrastructure/ or src/config/."
                ]
        if _is_submodule(module, "src"):
            return [
                f"{module} (import outside domain layer). "
                f"FIX: Domain code must only import from src.domain.* or stdlib."
            ]
        return []

    return [
        f"{module} (external dependency: {root}). "
        f"FIX: Third-party packages are not allowed in src/domain/. "
        f"If you need this functionality, wrap it in src/infrastructure/ "
        f"and pass it to domain via dependency injection."
    ]


def _check_relative_import(
    node: ast.ImportFrom,
    filepath: Path,
    domain_path: Path,
) -> list[str]:
    """Check relative imports for domain boundary violations."""
    violations: list[str] = []
    level = node.level or 0
    resolved_dir = _resolve_relative_target(filepath, domain_path, level)

    if resolved_dir is None:
        dots = "." * level
        module_part = node.module or ""
        names = ", ".join(a.name for a in node.names)
        import_str = f"from {dots}{module_part} import {names}"
        violations.append(
            f"{import_str} (relative import escapes domain boundary). "
            f"FIX: Use absolute imports (from src.domain.X import Y) within domain, "
            f"or reduce the relative import level to stay inside src/domain/."
        )
    return violations


def _check_dangerous_call(node: ast.Call) -> list[str]:
    """Detect dangerous dynamic import calls: __import__, exec, eval, compile,
    importlib.import_module, etc."""
    violations: list[str] = []

    if isinstance(node.func, ast.Name):
        if node.func.id in DANGEROUS_BUILTINS:
            violations.append(
                f"{node.func.id}() call at line {node.lineno} "
                f"(forbidden dynamic execution in domain). "
                f"FIX: Remove the {node.func.id}() call. Domain code must use "
                f"only static imports. If dynamic behavior is needed, implement it "
                f"in src/infrastructure/ and inject via interface."
            )

    elif isinstance(node.func, ast.Attribute):
        if node.func.attr in DANGEROUS_ATTR_CALLS:
            obj_name = _get_call_chain(node.func.value)
            violations.append(
                f"{obj_name}.{node.func.attr}() call at line {node.lineno} "
                f"(forbidden dynamic import in domain). "
                f"FIX: Replace with a static import, or move this logic to "
                f"src/infrastructure/ and expose it via a domain interface."
            )

    return violations


def _get_call_chain(node: ast.expr) -> str:
    """Reconstruct a dotted name from an AST expression (best-effort)."""
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        return f"{_get_call_chain(node.value)}.{node.attr}"
    return "<expr>"


def check_domain_purity(
    domain_path: Path,
    project_root: Path,
) -> list[tuple[Path, str]]:
    """Check domain layer for impurity violations across ALL .py files."""
    violations: list[tuple[Path, str]] = []

    if not domain_path.exists():
        return violations

    for py_file in domain_path.rglob("*.py"):
        file_violations = extract_violations(py_file, domain_path, project_root)
        for desc in file_violations:
            violations.append((py_file, desc))

    return violations


def main() -> int:
    env_root = os.environ.get("HARNESS_PROJECT_ROOT")
    if env_root:
        project_root = Path(env_root).resolve()
    else:
        script_dir = Path(__file__).parent.resolve()
        project_root = script_dir.parent.parent.parent

    domain_rel = os.environ.get("HARNESS_DOMAIN_PATH", "src/domain")
    domain_path = project_root / domain_rel
    result_file = sys.argv[1] if len(sys.argv) > 1 else None

    violations = check_domain_purity(domain_path, project_root)
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
