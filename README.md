# harness-core

> **KKD Agent-Native Standard (KKD-ANS) v2.0**
>
> Microkernel architecture for agent-driven development — configuration-driven, plugin-based, zero-inference verification.

## What is harness-core?

harness-core is a **microkernel-style verification framework** for AI agent workspaces. It provides the foundational infrastructure for environments where AI agents autonomously write, test, verify, and evolve code.

The system is built on a single principle: **`verify.sh` is the sole judge**. No human review, no guessing — only automated, reproducible, telemetry-backed verification.

## Architecture

```
                    harness.yaml
                   (Configuration Hub)
                         │
                         ▼
                    verify.sh
                   (Dispatcher)
          ┌────────┼────────┼────────┐
          ▼        ▼        ▼        ▼
       ruff      mypy    pytest   check_purity
       (lint)   (types)  (test)   (domain AST)
```

The dispatcher reads `harness.yaml`, bootstraps a virtual environment, runs each enabled plugin, generates `telemetry.json`, and auto-commits on all-pass.

## Directory Structure

```
harness-core/
├── harness.yaml                       # Microkernel config (project_type, module switches)
├── AGENTS.md                          # Agent protocol (read FIRST)
├── .harness/
│   ├── verify.sh                      # Dispatcher: YAML → plugins → telemetry
│   └── plugins/
│       ├── python/
│       │   ├── setup_env.sh           # .venv bootstrap (uv / venv fallback)
│       │   ├── run_linter.sh          # ruff
│       │   ├── run_typecheck.sh       # mypy
│       │   └── run_tests.sh           # pytest + coverage
│       ├── architecture/
│       │   └── check_purity.py        # Domain purity AST scanner
│       └── git/
│           └── auto_commit.sh         # Auto-commit on green
├── src/
│   ├── domain/                        # Pure business logic (Law 4)
│   ├── infrastructure/                # I/O, adapters
│   └── config/                        # Settings
├── tests/                             # Test files
└── docs/
    ├── ARCHITECTURE.md                # Architecture laws & plugin protocol
    ├── METRICS.md                     # Telemetry trend dashboard
    ├── PLANS.md                       # Development roadmap
    ├── design-docs/core-beliefs.md    # Foundational beliefs
    └── exec-plans/                    # Progress & feature backlog
```

## The 5 Architecture Laws

| Law | Name | Description |
|-----|------|-------------|
| **Law 1** | Isolation | `src/` and `.harness/` are strictly separated |
| **Law 2** | AI-Generated | All production code is AI-written |
| **Law 3** | Configuration | `harness.yaml` is the single source of truth |
| **Law 4** | Domain Purity | `src/domain/` — zero I/O, zero infra deps |
| **Law 5** | Telemetry | Every run emits `telemetry.json` via `json.dump()` |

## Quick Start

```bash
# 1. Clone
git clone <repo> && cd harness-core

# 2. Run verification (auto-creates .venv, installs tools, runs all checks)
bash .harness/verify.sh

# 3. If all green → automatic git commit with telemetry summary
```

No manual setup required. The `setup_env.sh` plugin auto-detects `uv` (preferred) or falls back to `python3 -m venv`.

## Configuration

Edit `harness.yaml` to control which modules run:

```yaml
version: 1.0
project_type: python

modules:
  linter:
    enabled: true       # set false to skip
    plugin: ruff
  type_checker:
    enabled: true
    plugin: mypy
  tests:
    enabled: true
  domain_purity:
    enabled: true
```

## The Autonomous Loop

```
┌─────────────────────────────────────────────────────────────┐
│  1. READ     harness.yaml → identify enabled modules        │
│  2. BOOTSTRAP setup_env.sh → .venv with toolchain           │
│  3. DISPATCH plugins in order → capture exit codes           │
│  4. TELEMETRY telemetry.json via json.dump()                 │
│  5. DECIDE   all green → auto_commit.sh                      │
│              any red  → report failures, abort               │
└─────────────────────────────────────────────────────────────┘
```

## Telemetry

Every run generates `telemetry.json`:

```json
{
  "timestamp": "2026-03-31T07:13:08Z",
  "task_id": "Task-027",
  "project_type": "python",
  "metrics": {
    "linter": { "exit_code": 0, "issues": 0, "tool": "ruff" },
    "type_checker": { "exit_code": 0, "issues": 0, "tool": "mypy" },
    "domain_purity": { "exit_code": 0, "issues": 0, "files_scanned": 1 },
    "tests": { "exit_code": 0, "passed": 1, "failed": 0, "coverage": { "percentage": 100 } }
  },
  "complexity": { "src_files": 4, "test_files": 1, "total_lines": 2 }
}
```

## Adding Plugins

1. Create script in `.harness/plugins/<category>/`
2. Follow the plugin protocol: exit 0/non-zero, optional JSON result file
3. Register in `harness.yaml` under `modules`
4. Add dispatch logic in `verify.sh`

## Quality Gates

| Gate | Tool | Threshold |
|------|------|-----------|
| Linting | ruff | 0 issues |
| Type Checking | mypy | 0 issues |
| Domain Purity | check_purity.py (AST) | pass |
| Test Coverage | pytest-cov | >= 80% |
| All Tests | pytest | 100% pass |

## License

MIT
