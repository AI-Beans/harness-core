# PLANS.md - Self-Evolving AI Lab

## Macro Goals

**Vision**: Build a fully autonomous coding agent system where AI writes, tests, and evolves code with zero human intervention.

## Phase 1 Achievements (Completed)

| Milestone | Status | Key Metrics |
|-----------|--------|-------------|
| Project Scaffolding | ✓ | Core framework established |
| Code Quality Gates | ✓ | Linter: 0 issues, Type checker: 0 issues |
| Test Infrastructure | ✓ | 62+ tests, 86%+ coverage |
| Domain Purity Enforcement | ✓ | check_purity.py enforces Law 4 (reference) |
| Self-Healing System | ✓ | Canary detection + circuit breaker |
| Resilience Evolution | ✓ | ResilientTimeAdapter implemented |

## Phase 2 Vision: Systematic Compliance & Scalability

**Objective**: Achieve full compliance with all 5 Architecture Laws and establish scalability patterns.

### Law Compliance Roadmap

#### Law 3 (Configuration Management) - In Progress
- **Current Gap**: Behavioral parameters hardcoded
- **Target**: All constants externalized to config/
- **Tasks**: Externalize canary tester parameters

#### Law 5 (Telemetry & Observability) - Planned
- **Current Gap**: Only latest telemetry stored, no trend analysis
- **Target**: Historical storage + predictive alerts
- **Tasks**: Add telemetry history

#### Complexity Enforcement - Planned
- **Current Gap**: Modules exceed 100-line threshold
- **Target**: All modules < 100 lines, SRP compliance
- **Tasks**: Module splitting

## Complexity Management Strategy

### Module Size Evolution
```
Phase 1 Start:  ~80 lines average
Phase 1 End:    ~77 lines average
Phase 2 Target: < 100 lines hard limit enforced
```

### Scaling Projection
Without enforcement, average module size will grow beyond limits. This violates the architectural principle of small, focused modules.

## Initial Feature List

See `docs/exec-plans/feature_list.json` for atomic task breakdown.

## Zero-Human Code Verification Gate

As an intelligent agent, use the appropriate language stack to construct a **CI/CD gate** that operates without human intervention:

### Architecture

```
[Code Change] → [Linter Check] → [Type Check] → [Unit Tests] → [Merge/Deploy]
                      ↓               ↓              ↓
              [LINTER_A]       [TYPE_CHECKER]   [TEST_FRAMEWORK]
              [LINTER_B]       [TYPE_CHECKER_B] [TEST_FRAMEWORK_B]
```

### Gate Philosophy
1. **Fail-fast**: Any check failure blocks progression
2. **Atomic commits**: Each task is discrete and verifiable
3. **Deterministic**: Same code always produces same results
4. **Self-documenting**: Progress tracked in `progress.txt`

### Implementation Strategy
1. All code must pass `[YOUR_LINTER]`
2. Type errors forbidden (`[YOUR_TYPE_CHECKER] --strict`)
3. Tests must achieve 80%+ coverage
4. No unsafe types allowed
5. All functions require proper typing

### Language Stack Reference

**Python** (example):
- Testing: pytest + pytest-cov
- Linting: ruff
- Type checking: mypy

**Node.js/TypeScript** (example):
- Testing: jest or vitest
- Linting: eslint
- Type checking: tsc --noEmit

**Go** (example):
- Testing: go test
- Linting: golangci-lint
- Type checking: go vet

**Rust** (example):
- Testing: cargo test
- Linting: rustfmt + clippy
- Type checking: rustc --emit=metadata
