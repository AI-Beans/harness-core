# Quality Score Codex

This document defines the quality metrics used to evaluate a self-evolving AI agent system.

## Telemetry Metrics

### Code Quality Gates

| Metric | Threshold | Source |
|--------|-----------|--------|
| Linter Issues | 0 | `[YOUR_LINTER] check .` |
| Type Checker Issues | 0 | `[YOUR_TYPE_CHECKER] .` |
| Domain Purity | pass | `.harness/check_purity.py` (reference plugin) |

### Test Coverage

| Metric | Threshold | Source |
|--------|-----------|--------|
| Line Coverage | ≥ 80% | `[YOUR_TEST_RUNNER] --coverage` |
| Domain Coverage | 100% (ideal) | Coverage report |

### Complexity Limits

| Metric | Limit | Enforcement |
|--------|-------|-------------|
| Module Lines | ≤ 100 | Manual review |
| Function Lines | ≤ 30 | Manual review |
| Cyclomatic Complexity | ≤ 10 | Manual review |

## Quality Indicators

### Green Zone (Healthy)
- Coverage ≥ 90%
- All 5 law checks passing
- No linting/type errors
- Canary tests passing

### Yellow Zone (Warning)
- Coverage 80-90%
- Minor linting warnings
- 1-2 laws partially compliant

### Red Zone (Critical)
- Coverage < 80%
- Any law violation
- Build failures
- Canary tests failing

## Score Calculation

```
Quality Score = (
  coverage_score * 0.4 +
  law_compliance_score * 0.3 +
  test_health_score * 0.3
)

Where:
- coverage_score = min(coverage / 90, 1.0) * 100
- law_compliance_score = (laws_passed / 5) * 100
- test_health_score = (tests_passed / total_tests) * 100
```

## Historical Targets

| Phase | Target Score | Notes |
|-------|--------------|-------|
| Phase 1 | ≥ 85 | Initial framework |
| Phase 2 | ≥ 90 | After Law 5 enhancement |
| Phase 3 | ≥ 95 | After full autonomy |
