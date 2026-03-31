# AGENTS.md — Harness-Core Agent Protocol v2.1

**Microkernel Architecture** — Configuration-driven, plugin-based, zero-inference verification.

## Quick Navigation

| Purpose | Path |
|---------|------|
| **Runtime Config** | `harness.yaml` |
| **Architecture Laws** | `docs/ARCHITECTURE.md` |
| **Core Beliefs** | `docs/design-docs/core-beliefs.md` |
| **Task Progress** | `docs/exec-plans/progress.txt` |
| **Quality Metrics** | `docs/METRICS.md` |

## Project Structure

```
./
├── AGENTS.md                          # ← You are here
├── harness.yaml                       # Microkernel config hub (read FIRST)
├── init.sh                            # One-command project bootstrap
├── src/
│   ├── domain/                        # Pure business logic (Law 4)
│   ├── infrastructure/                # I/O, adapters, telemetry
│   └── config/                        # Settings (Law 3)
├── tests/                             # Test files
├── docs/
│   ├── ARCHITECTURE.md
│   ├── PLANS.md
│   ├── METRICS.md
│   ├── design-docs/
│   ├── exec-plans/
│   └── references/
└── .harness/                          # CI/CD microkernel
    ├── verify.sh                      # Dispatcher: parses harness.yaml → runs plugins
    └── plugins/
        ├── python/                    # Python toolchain plugins
        │   ├── setup_env.sh           #   .venv bootstrap (uv / venv fallback)
        │   ├── run_linter.sh          #   ruff
        │   ├── run_typecheck.sh       #   mypy
        │   └── run_tests.sh           #   pytest + coverage
        ├── architecture/              # Architecture enforcement plugins
        │   └── check_purity.py        #   Domain purity (Law 4)
        └── git/                       # Post-verification plugins
            └── auto_commit.sh         #   Auto-commit on all-pass
```

## The 5 Architecture Laws

| Law | Name | Agent Rule |
|-----|------|------------|
| **Law 1** | Isolation | `.harness/` is never imported by `src/`. Read `harness.yaml` before any task. |
| **Law 2** | Zero-Inference Verification | `verify.sh` is the sole judge. Run it before reporting done. If it fails, self-fix (see Fuse Rule). |
| **Law 3** | Configuration | All behavior externalized. No magic constants. `harness.yaml` is the source of truth. |
| **Law 4** | Domain Purity | `src/domain/` may only import stdlib + `src.domain.*`. Cross-layer imports are auto-rejected. |
| **Law 5** | Telemetry | Every run generates `telemetry.json` + appends to `.telemetry_history.json`. Update `progress.txt` after each green run. |

### Law 2 — Fuse Rule (Critical)

**Maximum retry limit**: If `verify.sh` fails, you MUST attempt to self-fix and re-run. However:

- **Maximum 5 consecutive retries** on the same verification failure.
- After 5 failures on the same issue, **STOP**.
- Write a detailed failure report in `docs/exec-plans/progress.txt` including:
  - The exact error output from verify.sh
  - What you attempted to fix
  - Why you believe the issue cannot be resolved automatically
- Then report the situation to the user and wait for guidance.

### Law 4 — Domain Purity (Critical)

The `check_purity.py` AST scanner enforces:

- **ALLOWED**: `typing`, `collections.abc`, `contextlib`, `functools`, `itertools`, `types`, `dataclasses`, `enum`, `abc`, `re`, `math`, `datetime`, `decimal`, `copy`, `operator`, `string`, `uuid`, `src.domain.*`
- **BLOCKED**: `src.infrastructure.*`, `src.config.*`, any third-party package

The scanner detects:
1. **Static imports**: Full import paths — `from src.infrastructure.logger import Logger` is caught.
2. **Dynamic imports**: Calls to `__import__()`, `exec()`, `eval()`, `compile()` are forbidden in domain code.
3. **importlib calls**: `importlib.import_module()`, `importlib.find_module()`, `importlib.find_spec()` are forbidden.
4. **Relative imports**: `from .. import infrastructure` is caught when it escapes the domain boundary.

**You MUST NOT use dynamic import mechanisms in `src/domain/`.**

## Configuration

`harness.yaml` is the single source of truth:

```yaml
version: 1.0
project_type: python

plugin_timeout: 300           # seconds per plugin (default: 300)

paths:
  domain: src/domain          # for check_purity.py
  src: src                    # for mypy + pytest --cov
  tests: tests                # for test discovery

modules:
  linter:
    enabled: true
    plugin: ruff
  type_checker:
    enabled: true
    plugin: mypy
  tests:
    enabled: true
    coverage_threshold: 80    # minimum line coverage percentage
  domain_purity:
    enabled: true
```

## Verification

```bash
# Run full verification gate
bash .harness/verify.sh

# With task ID:
bash .harness/verify.sh TASK-042
```

The dispatcher:
1. Validates `python3` is available (fails fast if not)
2. Reads `harness.yaml` (fails fast if parse produces no config)
3. Validates `project_type` is non-empty and supported
4. Bootstraps `.venv` via `setup_env.sh` (with pinned toolchain versions)
5. Runs each enabled plugin with configurable timeout
6. Generates `telemetry.json` + appends to history
7. Fails if zero plugins were dispatched
8. Auto-commits on all-pass (explicit file staging)

## Build/Lint/Test Commands

```bash
bash .harness/plugins/python/run_linter.sh
bash .harness/plugins/python/run_typecheck.sh
bash .harness/plugins/python/run_tests.sh
python3 .harness/plugins/architecture/check_purity.py

bash .harness/verify.sh
```

## Code Style

- Python: enforced by ruff
- Type hints: enforced by mypy on `src/`

## Error Handling

- Always handle errors explicitly
- Use specific error types
- Never swallow exceptions silently
- Plugins exit non-zero on failure, zero on success
- Plugins are killed after `plugin_timeout` seconds (default 300)

## Development Workflow

1. **Plan**: Read `harness.yaml` → check `docs/exec-plans/feature_list.json`
2. **Implement**: Follow 5 Architecture Laws
3. **Verify**: Run `bash .harness/verify.sh` — fix until green (max 5 retries per issue)
4. **Record**: Update `docs/exec-plans/progress.txt`
