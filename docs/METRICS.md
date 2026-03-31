# METRICS.md — Telemetry Trend Dashboard

This file is the single source of truth for quality metrics. It replaces the former
`QUALITY_SCORE.md` and `RELIABILITY.md` with a lightweight, telemetry-driven format.

Every successful `verify.sh` run generates `telemetry.json`, which is the canonical
metrics record. Below is the current snapshot.

## Current Snapshot

| Metric | Value |
|--------|-------|
| Linter | ruff — 0 issues |
| Type Checker | mypy — 0 issues |
| Domain Purity | 0 violations |
| Tests | 1 passed, 0 failed |
| Coverage | 100% (threshold: 80%) |
| Project Type | python |

## Trend

| Date | Task | Linter | MyPy | Purity | Tests | Coverage |
|------|------|--------|------|--------|-------|----------|
| 2026-03-31 | Task-026 | ✓ 0 | ✓ 0 | ✓ 0 | ✓ 1/0 | 100% |
| 2026-03-31 | Task-025 | ✓ 0 | ✓ 0 | ✓ 0 | ✓ 1/0 | 100% |

## Interpretation

- **All green**: system is at production-grade quality.
- **Coverage drops below 80%**: investigate missing test paths.
- **Domain purity violation**: stop and fix architecture before proceeding.
