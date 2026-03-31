"""Adversarial tests for check_purity.py — Law 4 enforcement.

These tests verify that the AST scanner catches all known bypass vectors:
  - Static cross-layer imports
  - Dynamic imports (__import__, exec, eval, compile)
  - importlib.import_module() calls
  - Relative imports escaping domain boundary
  - Third-party package imports

Each test creates a temporary Python file in a synthetic domain directory
and runs the scanner against it.
"""

import textwrap
from pathlib import Path

import pytest

from importlib.util import spec_from_file_location, module_from_spec

CHECKER_PATH = Path(__file__).parent.parent / ".harness" / "plugins" / "architecture" / "check_purity.py"


def _load_checker():
    spec = spec_from_file_location("check_purity", CHECKER_PATH)
    assert spec and spec.loader
    mod = module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


checker = _load_checker()


@pytest.fixture()
def domain_tree(tmp_path: Path):
    """Create a minimal project structure with src/domain/."""
    domain = tmp_path / "src" / "domain"
    domain.mkdir(parents=True)
    (domain / "__init__.py").touch()
    return domain


def _write_and_scan(domain: Path, code: str, filename: str = "target.py"):
    filepath = domain / filename
    filepath.write_text(textwrap.dedent(code))
    project_root = domain.parent.parent
    return checker.extract_violations(filepath, domain, project_root)


class TestStaticImports:
    """Verify static import detection (original functionality)."""

    def test_stdlib_allowed(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            from typing import Optional
            from dataclasses import dataclass
            import enum
            import abc
            import re
            import uuid
        """)
        assert violations == []

    def test_domain_self_import_allowed(self, domain_tree: Path):
        sub = domain_tree / "models"
        sub.mkdir()
        (sub / "__init__.py").touch()
        violations = _write_and_scan(domain_tree, """
            from src.domain.models import SomeModel
        """)
        assert violations == []

    def test_infrastructure_import_blocked(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            from src.infrastructure.logger import Logger
        """)
        assert len(violations) == 1
        assert "cross-layer" in violations[0]

    def test_config_import_blocked(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            from src.config.settings import Settings
        """)
        assert len(violations) == 1
        assert "cross-layer" in violations[0]

    def test_third_party_blocked(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            import requests
        """)
        assert len(violations) == 1
        assert "external dependency" in violations[0]

    def test_import_os_blocked(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            import os
        """)
        assert len(violations) == 1
        assert "external dependency" in violations[0]


class TestDynamicImportBypass:
    """CVE-H2: Verify dynamic import mechanisms are caught."""

    def test_dunder_import_caught(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            db = __import__("src.infrastructure.database")
        """)
        assert any("__import__" in v for v in violations)

    def test_exec_caught(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            exec("from src.infrastructure.logger import Logger")
        """)
        assert any("exec" in v for v in violations)

    def test_eval_caught(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            mod = eval("__import__('os')")
        """)
        assert any("eval" in v for v in violations)

    def test_compile_caught(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            code = compile("import os", "<string>", "exec")
        """)
        assert any("compile" in v for v in violations)

    def test_importlib_import_module_caught(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            import importlib
            logger = importlib.import_module("src.infrastructure.logger")
        """)
        assert any("import_module" in v for v in violations)
        assert any("importlib" in v or "external dependency" in v for v in violations)

    def test_dunder_import_without_any_imports(self, domain_tree: Path):
        """__import__ is a builtin — no import statement needed."""
        violations = _write_and_scan(domain_tree, """
            db = __import__("src.infrastructure.database")
            db.connect()
        """)
        assert any("__import__" in v for v in violations)


class TestRelativeImportBypass:
    """CVE-H3: Verify relative imports that escape domain are caught."""

    def test_relative_import_escaping_domain(self, domain_tree: Path):
        sub = domain_tree / "subpackage"
        sub.mkdir()
        (sub / "__init__.py").touch()
        filepath = sub / "module.py"
        filepath.write_text("from .. import infrastructure\n")
        project_root = domain_tree.parent.parent
        violations = checker.extract_violations(filepath, domain_tree, project_root)
        assert violations == [], (
            "from .. import infrastructure within domain stays in domain — "
            "level=2 from subpackage goes to domain root"
        )

    def test_deep_relative_import_escaping_domain(self, domain_tree: Path):
        """from ... import X from a direct child of domain/ escapes to src/."""
        sub = domain_tree / "subpackage"
        sub.mkdir()
        (sub / "__init__.py").touch()
        filepath = sub / "module.py"
        filepath.write_text("from ... import infrastructure\n")
        project_root = domain_tree.parent.parent
        violations = checker.extract_violations(filepath, domain_tree, project_root)
        assert len(violations) >= 1
        assert any("escapes domain" in v for v in violations)

    def test_relative_import_within_domain_ok(self, domain_tree: Path):
        sub = domain_tree / "models"
        sub.mkdir()
        (sub / "__init__.py").touch()
        (sub / "entity.py").write_text("X = 1\n")
        filepath = sub / "service.py"
        filepath.write_text("from . import entity\n")
        project_root = domain_tree.parent.parent
        violations = checker.extract_violations(filepath, domain_tree, project_root)
        assert violations == []

    def test_relative_import_with_module_escaping(self, domain_tree: Path):
        """from ...config import settings — relative import with module name."""
        sub = domain_tree / "subpackage"
        sub.mkdir()
        (sub / "__init__.py").touch()
        filepath = sub / "module.py"
        filepath.write_text("from ...config import settings\n")
        project_root = domain_tree.parent.parent
        violations = checker.extract_violations(filepath, domain_tree, project_root)
        assert len(violations) >= 1
        assert any("escapes domain" in v for v in violations)


class TestEdgeCases:
    def test_empty_file(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, "")
        assert violations == []

    def test_syntax_error_skipped(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            def broken(
        """)
        assert violations == []

    def test_multiple_violations_in_one_file(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            import os
            from src.infrastructure.db import DB
            exec("import sys")
            __import__("requests")
        """)
        assert len(violations) >= 4

    def test_no_domain_dir_returns_empty(self, tmp_path: Path):
        fake_domain = tmp_path / "nonexistent"
        result = checker.check_domain_purity(fake_domain, tmp_path)
        assert result == []


class TestFixInstructions:
    """Verify that violation messages include actionable FIX guidance."""

    def test_cross_layer_has_fix(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            from src.infrastructure.db import DB
        """)
        assert len(violations) == 1
        assert "FIX:" in violations[0]
        assert "interface" in violations[0].lower()

    def test_external_dep_has_fix(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            import requests
        """)
        assert len(violations) == 1
        assert "FIX:" in violations[0]
        assert "src/infrastructure/" in violations[0]

    def test_dynamic_import_has_fix(self, domain_tree: Path):
        violations = _write_and_scan(domain_tree, """
            __import__("os")
        """)
        assert any("FIX:" in v for v in violations)

    def test_relative_escape_has_fix(self, domain_tree: Path):
        sub = domain_tree / "subpackage"
        sub.mkdir()
        (sub / "__init__.py").touch()
        filepath = sub / "module.py"
        filepath.write_text("from ... import infrastructure\n")
        project_root = domain_tree.parent.parent
        violations = checker.extract_violations(filepath, domain_tree, project_root)
        assert len(violations) >= 1
        assert any("FIX:" in v for v in violations)
