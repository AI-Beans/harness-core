# ARCHITECTURE.md - KKD-ANS v2.0 Microkernel

## System Architecture

### Microkernel Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                     harness.yaml                            │
│               (Configuration Hub — Law 3)                   │
│  project_type: python                                       │
│  modules: { linter, type_checker, tests, domain_purity }    │
└──────────────┬──────────────────────────────────────────────┘
               │ parsed by dispatcher
               ▼
┌─────────────────────────────────────────────────────────────┐
│                   .harness/verify.sh                        │
│                (Dispatcher — Law 2 Judge)                   │
│  reads harness.yaml → dispatches enabled plugins            │
│  captures results → generates telemetry.json                │
└──────┬──────────┬──────────┬──────────┬─────────────────────┘
       │          │          │          │
       ▼          ▼          ▼          ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────────┐
│ run_      ││ run_      ││ run_      ││ check_       │
│ linter.sh ││ typecheck ││ tests.sh ││ purity.py    │
│ (ruff)    ││ .sh(myPy) ││(pytest)  ││(AST scanner) │
└──────────┘└──────────┘└──────────┘└──────────────┘
     plugins/python/                      plugins/architecture/
```

### Layered Application

```
┌─────────────────────────────────────────────────────────────┐
│                     presentation/                          │
│                   (CLI, APIs, UI)                          │
├─────────────────────────────────────────────────────────────┤
│                      domain/                               │
│              (Business Logic, Entities)                     │
├─────────────────────────────────────────────────────────────┤
│                    infrastructure/                         │
│           (Logging, Storage, External Services)              │
├─────────────────────────────────────────────────────────────┤
│                      config/                               │
│           (Environment Variables, Settings)                 │
└─────────────────────────────────────────────────────────────┘
```

## Hard Boundaries (Immutable Laws)

### Law 1: src/ vs .harness/ Isolation

```
┌──────────────────────────────────────────────────────────────────┐
│  src/                                                              │
│  ├── domain/     → Business logic only, no I/O, no external deps  │
│  ├── infrastructure/ → Logger, storage adapters, external clients │
│  └── config/     → Settings loader, env var access                │
│                                                                  │
│  .harness/ (OPERATIONAL TOOLING, NOT PART OF APPLICATION CODE)  │
│  ├── verify.sh        → Dispatcher: parses harness.yaml           │
│  └── plugins/         → Isolated toolchain scripts                │
│      ├── python/      → ruff, mypy, pytest                        │
│      └── architecture/→ check_purity.py                           │
│                                                                  │
│  ENFORCEMENT: .harness/ is never importable by src/              │
└──────────────────────────────────────────────────────────────────┘
```

**Rationale**: `.harness/` contains operational tooling dispatched by `verify.sh`. Application code in `src/` must remain pure business logic, testable without running CI/CD scripts.

### Law 2: Zero-Inference Verification

`verify.sh` is the sole judge. No human review.

- Before reporting "done", run `verify.sh`.
- If it exits non-zero, read errors, self-fix, re-run.
- Never ask for help on a red build.

### Law 3: Configuration Management

```
┌──────────────────────────────────────────────────────────────────┐
│  harness.yaml — Single source of truth for verification           │
│                                                                  │
│  Controls:                                                       │
│  - project_type (python, node, go, ...)                          │
│  - module enable/disable switches                                │
│  - plugin assignments per module                                 │
│                                                                  │
│  src/config/ — Application-level settings                        │
│  - Environment variable access with validation                   │
│  - Type-safe configuration models                                │
│                                                                  │
│  PROHIBITED:                                                    │
│  ✗ Hardcoded credentials in source code                         │
│  ✗ Magic numbers without named constants                        │
│  ✗ Import-time side effects from config                         │
└──────────────────────────────────────────────────────────────────┘
```

### Law 4: Domain Purity

```
src/domain/ rules:
├── NO imports from src/infrastructure/
├── NO imports from src/config/
├── NO file I/O operations
├── NO network calls
├── NO environment variable access
└── Only: stdlib (typing, collections.abc, contextlib, functools,
         itertools, types, dataclasses, enum, abc) + src.domain.*
```

**Enforcement**: `.harness/plugins/architecture/check_purity.py` performs AST-level scanning of ALL `.py` files under `src/domain/`. It checks full import paths — not just root segments — so `from src.infrastructure.logger import Logger` is correctly caught as a violation despite the root being `src`.

### Law 5: Telemetry & Observability

Every `verify.sh` execution generates `telemetry.json` via `json.dump()`:
- Timestamp, task_id
- Per-plugin: exit_code, issues count, tool name
- Test metrics: passed/failed, coverage percentage
- Complexity metrics: src_files, test_files, total_lines

**No heredoc injection** — all JSON generation uses Python's `json` module.

## Directory Structure

```
harness-core/
├── AGENTS.md                          # Agent entry point & protocol
├── README.md                          # Project overview
├── harness.yaml                       # Microkernel configuration hub
├── .gitignore                         # VCS exclusions
├── telemetry.json                     # Generated by verify.sh
├── src/
│   ├── __init__.py
│   ├── domain/                        # Pure business logic
│   │   └── __init__.py
│   ├── infrastructure/                # I/O, adapters, telemetry
│   │   └── __init__.py
│   └── config/                        # Settings loader
│       └── __init__.py
├── tests/
│   ├── __init__.py
│   └── test_skeleton.py
├── docs/
│   ├── ARCHITECTURE.md                # This file
│   ├── PLANS.md
│   ├── METRICS.md
│   ├── design-docs/
│   │   └── core-beliefs.md
│   ├── exec-plans/
│   │   ├── progress.txt
│   │   └── feature_list.json
│   └── references/
└── .harness/                          # CI/CD microkernel
    ├── verify.sh                      # Dispatcher (parses harness.yaml)
    └── plugins/
        ├── python/
        │   ├── setup_env.sh           # .venv bootstrap (uv / venv fallback)
        │   ├── run_linter.sh          # ruff check
        │   ├── run_typecheck.sh       # mypy src/
        │   └── run_tests.sh           # pytest --cov=src
        ├── architecture/
        │   └── check_purity.py        # AST domain purity scanner
        └── git/
            └── auto_commit.sh         # Auto-commit on all-pass
```

## Technology Stack

| Layer | Tool |
|-------|------|
| Language | Python 3.10+ |
| Package Manager | uv (preferred) / pip fallback |
| Linting | ruff |
| Type Checking | mypy |
| Testing | pytest + pytest-cov |
| Config | harness.yaml (YAML) |
| Telemetry | json.dump() (Python stdlib) |
| VCS | git (auto-commit on green) |

## Enforcement

1. **CI/CD Gate** (verify.sh dispatcher):
   - Reads `harness.yaml` for enabled modules
   - Dispatches each enabled plugin in order
   - Captures exit codes independently (no short-circuit)
   - Generates `telemetry.json` with all results
   - Auto-commits on all-pass

2. **Import Boundaries**:
   - `check_purity.py` enforces no infrastructure/config imports in domain
   - AST-level scan catches all violations across ALL `.py` files
   - Full path checking prevents `src.*` bypass

3. **Coverage Gate**:
   - 80% minimum line coverage (configurable)
   - Parsed via Python `re` module (no fragile grep/awk pipes)

## Plugin Protocol

Each plugin must:
1. Use `set -euo pipefail` (shell) or proper error handling (Python)
2. Exit 0 on success, non-zero on failure
3. Optionally accept a result file path as `$1` / `sys.argv[1]`
4. Write a JSON result with at minimum: `{"exit_code": N, "tool": "...", "issues": N}`
