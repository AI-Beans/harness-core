# PLANS.md — Development Roadmap

## Current Status

This project is at the **microkernel framework bootstrap** stage. The verification infrastructure is functional; application code does not yet exist.

## Completed Tasks

| Task | Description |
|------|-------------|
| Task-025 | Microkernel refactoring with legacy migration |
| Task-026 | Environment bootstrapping (.venv auto-heal) |
| Task-027 | Auto-commit plugin + doc cleanup |
| Task-028 | Structure audit, .gitignore, README rewrite |

## Next Steps

1. Write actual domain logic in `src/domain/`
2. Write corresponding tests in `tests/`
3. Expand `harness.yaml` with coverage thresholds matching real code
4. Add telemetry history tracking

## Task Backlog

See `docs/exec-plans/feature_list.json` for atomic task breakdown.
