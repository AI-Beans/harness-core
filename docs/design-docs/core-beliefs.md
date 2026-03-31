# Core Beliefs — Architecture Philosophy

## 1. Autonomy First

Every system component must operate without human intervention. If a human is required to make a decision, the system has failed.

## 2. Verification Before Creation

- No code is merged without passing all gates
- Tests are written **before** implementation (TDD mindset for AI)
- Linting and type-checking are non-negotiable

## 3. Fail Fast, Recover Faster

When something breaks:
1. Detect immediately
2. Log the failure with context
3. Attempt automatic recovery if possible (max 5 retries — Fuse Rule)
4. Escalate only if unrecoverable

## 4. Everything is Trackable

- Every verification run recorded in `telemetry.json` + `.telemetry_history.json`
- Every task tracked in `docs/exec-plans/progress.txt`
- No unmarked changes, no silent failures

## 5. Incremental Evolution

- Large goals decomposed into atomic tasks
- Each task is independently verifiable
- Success = all atomic tasks complete

## 6. Zero Tolerance for Code Pollution

- No `any` types
- No commented-out code
- No TODO comments without issue tracking
- Strict formatting standards

## 7. Domain Purity is Mechanically Enforced

`check_purity.py` uses AST analysis to enforce that `src/domain/` only imports stdlib and `src.domain.*`. It detects:
- Static imports (import / from ... import)
- Dynamic imports (__import__, exec, eval, compile)
- importlib.import_module() calls
- Relative imports that escape the domain boundary
