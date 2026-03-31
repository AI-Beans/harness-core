# AGENTS.md — Map & Protocol

> This file is a map, not an encyclopedia. It tells you where to look, not everything you need to know.

## Session Protocol

### On Every Session Start

1. Run `pwd` to confirm your working directory.
2. Read `docs/exec-plans/progress.md` and `git log --oneline -20` to understand recent work.
3. Read `docs/exec-plans/feature_list.json` — pick the highest-priority feature where `"passes": false`.
4. Run `bash .harness/verify.sh` to confirm the codebase is in a clean state. Fix any failures before starting new work.

### On Every Session End

1. Run `bash .harness/verify.sh` — fix until green (max 5 retries per issue; see Fuse Rule below).
2. `git commit` with a descriptive message summarizing what changed and why.
3. Append a progress entry to `docs/exec-plans/progress.md` describing what you did, what you decided, and what the next agent should do.
4. Update `docs/exec-plans/feature_list.json` — mark completed features as `"passes": true`. **Never remove or edit feature descriptions.**

## Where to Find Things

| What you need | Where to look |
|---------------|---------------|
| **What to build** | `docs/exec-plans/feature_list.json` |
| **What was done recently** | `docs/exec-plans/progress.md` + `git log` |
| **Active execution plans** | `docs/exec-plans/active/` |
| **Completed plans** | `docs/exec-plans/completed/` |
| **Architecture rules** | `docs/ARCHITECTURE.md` |
| **Domain boundaries** | `docs/ARCHITECTURE.md` → Law 4 section |
| **Quality scores by area** | `docs/QUALITY_SCORE.md` |
| **Core design beliefs** | `docs/design-docs/core-beliefs.md` |
| **Runtime config** | `harness.yaml` (read this FIRST on any task) |
| **Reference docs (LLM-friendly)** | `docs/references/` |

## Immutable Rules

### Law 1 — Isolation

`.harness/` is operational tooling. `src/` is application code. They never import each other.

### Law 2 — Verification + Fuse Rule

`verify.sh` is the sole judge. Run it before reporting done.

**Fuse Rule**: Max 5 consecutive retries on the same failure. After 5, STOP. Write a failure report in `docs/exec-plans/progress.md` with the exact error, what you tried, and why it cannot be auto-fixed. Then wait for human guidance.

### Law 3 — Configuration

`harness.yaml` is the single source of truth. No magic constants in code.

### Law 4 — Domain Purity

`src/domain/` may only import stdlib allowlist + `src.domain.*`. The AST scanner also blocks `__import__()`, `exec()`, `eval()`, `compile()`, and `importlib.import_module()`. Relative imports that escape domain boundary are caught. See `docs/ARCHITECTURE.md` for the full allowlist.

### Law 5 — Telemetry

Every `verify.sh` run generates `telemetry.json` + appends to `.telemetry_history.json`.

## Verification

```bash
bash .harness/verify.sh           # full gate
bash .harness/verify.sh TASK-042  # with task ID
```

## Build Commands

```bash
bash .harness/plugins/python/run_linter.sh
bash .harness/plugins/python/run_typecheck.sh
bash .harness/plugins/python/run_tests.sh
python3 .harness/plugins/architecture/check_purity.py
```

## Code Style

- Python: ruff enforced. mypy enforced on `src/`.
- No comments unless they explain non-obvious intent.
- Handle errors explicitly; never swallow exceptions.
