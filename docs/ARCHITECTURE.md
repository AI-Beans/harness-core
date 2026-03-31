# ARCHITECTURE.md - KKD-ANS v2.1 Microkernel

## System Architecture

### Microkernel Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                     harness.yaml                            │
│               (Configuration Hub — Law 3)                   │
│  project_type: python                                       │
│  plugin_timeout: 300                                        │
│  paths: { domain, src, tests }                              │
│  modules: { linter, type_checker, tests, domain_purity }    │
└──────────────┬──────────────────────────────────────────────┘
               │ parsed by dispatcher (inline comments stripped)
               ▼
┌─────────────────────────────────────────────────────────────┐
│                   .harness/verify.sh                        │
│                (Dispatcher — Law 2 Judge)                   │
│  validates python3 + config → dispatches plugins w/ timeout │
│  captures results → generates telemetry → appends history   │
│  fails fast on: no python3, empty config, bad project_type  │
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
│  ├── verify.sh              → Dispatcher: parses harness.yaml     │
│  ├── requirements-toolchain.txt → Pinned tool versions (optional) │
│  └── plugins/               → Isolated toolchain scripts          │
│      ├── python/            → ruff, mypy, pytest                  │
│      ├── architecture/      → check_purity.py                     │
│      └── git/               → auto_commit.sh                      │
│                                                                  │
│  ENFORCEMENT: .harness/ is never importable by src/              │
└──────────────────────────────────────────────────────────────────┘
```

### Law 2: Zero-Inference Verification

`verify.sh` is the sole judge. No human review.

- Before reporting "done", run `verify.sh`.
- If it exits non-zero, read errors, self-fix, re-run.
- **Fuse Rule**: Maximum 5 consecutive retries on the same failure. After that, stop and report in `progress.txt`.
- Never ask for help on a red build (until fuse blows).

### Law 3: Configuration Management

```
┌──────────────────────────────────────────────────────────────────┐
│  harness.yaml — Single source of truth for verification           │
│                                                                  │
│  Controls:                                                       │
│  - project_type (python, node, go, ...)                          │
│  - plugin_timeout (seconds per plugin, default 300)              │
│  - paths.domain, paths.src, paths.tests                          │
│  - module enable/disable switches                                │
│  - coverage_threshold per test module                            │
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
├── NO dynamic imports (__import__, exec, eval, compile)
├── NO importlib.import_module() or similar
├── NO relative imports that escape domain boundary
└── Only: stdlib (typing, collections.abc, contextlib, functools,
         itertools, types, dataclasses, enum, abc, re, math,
         datetime, decimal, copy, operator, string, uuid) + src.domain.*
```

**Enforcement**: `.harness/plugins/architecture/check_purity.py` performs AST-level scanning of ALL `.py` files under `src/domain/`. It checks:

1. **Static imports** (ast.Import, ast.ImportFrom) — full path checking
2. **Dynamic imports** — calls to `__import__()`, `exec()`, `eval()`, `compile()`, `importlib.import_module()`, `importlib.find_module()`, `importlib.find_spec()`
3. **Relative imports** — boundary resolution ensures `from ..` cannot escape domain

### Law 5: Telemetry & Observability

Every `verify.sh` execution:
- Generates `telemetry.json` (latest run snapshot)
- Appends to `.telemetry_history.json` (capped at 100 entries)
- Records timestamp, task_id, per-plugin metrics, complexity metrics

All JSON generation uses Python's `json` module (no heredoc injection).

Violation messages include actionable **FIX** instructions that are injected into the agent's context, enabling self-repair without consulting external documentation.

## Knowledge Base Layout

```
docs/
├── ARCHITECTURE.md            # This file — architecture laws & technical spec
├── PLANS.md                   # Development roadmap
├── METRICS.md                 # Telemetry dashboard
├── QUALITY_SCORE.md           # Per-domain quality assessment (A-F grades)
├── design-docs/
│   ├── core-beliefs.md        # Foundational design principles
│   └── ...                    # Feature-specific design docs
├── exec-plans/
│   ├── progress.md            # Session handoff log (append-only)
│   ├── feature_list.json      # Structured features with pass/fail tracking
│   ├── active/                # Current execution plans
│   └── completed/             # Archived execution plans
└── references/                # LLM-friendly reference material
```

**AGENTS.md** (~70 lines) serves as a map/table of contents pointing into this structure. It is NOT an encyclopedia — keep it short. Detailed rules live here and in sub-documents.

## Configuration Reference

```yaml
version: 1.0
project_type: python

plugin_timeout: 300           # max seconds per plugin (default: 300)

paths:
  domain: src/domain          # domain purity scan target
  src: src                    # mypy + coverage target
  tests: tests                # test discovery root

modules:
  linter:
    enabled: true
    plugin: ruff
  type_checker:
    enabled: true
    plugin: mypy
  tests:
    enabled: true
    coverage_threshold: 80    # minimum line coverage %
  domain_purity:
    enabled: true
```

### Environment Variables

All scripts respect these overrides for Submodule integration:

| Variable | Default | Purpose |
|----------|---------|---------|
| `HARNESS_PROJECT_ROOT` | auto-detected | Host project root when used as Submodule |
| `HARNESS_DOMAIN_PATH` | from harness.yaml `paths.domain` | Domain purity scan target |
| `HARNESS_SRC_PATHS` | from harness.yaml `paths.src` | MyPy + coverage target |
| `HARNESS_TEST_PATHS` | from harness.yaml `paths.tests` | Test discovery root |
| `HARNESS_COVERAGE_THRESHOLD` | from harness.yaml | Minimum coverage % |

## Plugin Protocol

Each plugin must:
1. Use `set -euo pipefail` (shell) or proper error handling (Python)
2. Exit 0 on success, non-zero on failure
3. Optionally accept a result file path as `$1` / `sys.argv[1]`
4. Write a JSON result with at minimum: `{"exit_code": N, "tool": "...", "issues": N}`
5. Complete within `plugin_timeout` seconds or be killed

## Technology Stack

| Layer | Tool |
|-------|------|
| Language | Python 3.10+ |
| Package Manager | uv (preferred) / pip fallback |
| Linting | ruff (version-pinned) |
| Type Checking | mypy (version-pinned) |
| Testing | pytest + pytest-cov (version-pinned) |
| Config | harness.yaml (YAML with inline comment support) |
| Telemetry | json.dump() (Python stdlib) with history |
| VCS | git (explicit file staging, not git add -A) |

## Enforcement

1. **CI/CD Gate** (verify.sh dispatcher):
   - Validates python3 availability (fails fast if missing)
   - Reads `harness.yaml` with inline comment stripping
   - Validates config is non-empty and project_type is supported
   - Dispatches each enabled plugin with configurable timeout
   - Generates `telemetry.json` + appends to history
   - Fails if zero plugins dispatched
   - Auto-commits on all-pass (explicit file staging)

2. **Import Boundaries** (check_purity.py):
   - Static imports: full path checking
   - Dynamic imports: __import__, exec, eval, compile detection
   - Attribute calls: importlib.import_module detection
   - Relative imports: boundary-aware resolution
   - AST-level scan catches all violations across ALL `.py` files

3. **Coverage Gate**:
   - Threshold configurable via harness.yaml (default 80%)
   - Parsed via Python `re` module (no fragile grep/awk pipes)
