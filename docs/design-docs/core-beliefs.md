# Core Beliefs - Architecture Philosophy

## Fundamental Principles

### 1. Autonomy First
Every system component must operate without human intervention. If a human is required to make a decision, the system has failed.

### 2. Verification Before Creation
- No code is merged without passing all gates
- Tests are written **before** implementation (TDD mindset for AI)
- Linting and type-checking are non-negotiable

### 3. Fail Fast, Recover Faster
When something breaks:
1. Detect immediately
2. Log the failure with context
3. Attempt automatic recovery if possible
4. Escalate only if unrecoverable

### 4. Everything is Trackable
- Every action recorded in `progress.txt`
- Every feature tracked in `.harness/feature_list.json`
- No unmarked changes, no silent failures

### 5. Incremental Evolution
- Large goals decomposed into atomic tasks
- Each task is independently verifiable
- Success = all atomic tasks complete

### 6. Language-Agnostic Core
- Python for scripting, ML, data processing
- Node.js for web services, tooling, package management
- Choose the right tool for each job

### 7. Zero Tolerance for Code Pollution
- No `any` types
- No commented-out code
- No TODO comments without issue tracking
- Strict formatting standards

### 8. Mechanical Taste (Law Enforcement Evolution)
**Discovered**: 2026-03-30

Law 4 (Domain Purity) enforcement revealed a gap in our tooling:

**The Problem**:
- import-linter v2.11 has a parsing bug with external module forbidden rules
- Ruff only catches unused imports (F401), not imports used in domain layer
- MyPy doesn't currently enforce "no external imports" in domain

**The Experiment**:
1. Injected `import os` with actual usage (`os.getcwd()`) in `src/domain/__init__.py`
2. Ruff: Passed (os was "used")
3. MyPy: Passed (no type errors)
4. import-linter: Failed to run due to configuration bug

**The Limitation**:
Current tools cannot mechanically enforce "domain layer must be pure stdlib-only imports".
This is a **known gap** - AI agents must self-regulate when writing domain code.

**The Evolution**:
This discovery marks a milestone in our "Mechanical Taste" - the system now
understands its own limitations and can identify gaps in automated enforcement.
Future improvement: custom ruff plugin or alternative tooling (e.g., pydeps).

**Implication**:
AI agents must exercise "taste" when writing domain code. The system will:
1. Log any detected domain impurity violations
2. Attempt self-healing when violations are found
3. Document limitations that cannot be mechanically enforced


## 9. Resilience Evolution (2026-03-31)

**Challenge**: Infrastructure components can exhibit non-deterministic behavior (e.g., 10% fault injection in TimeAdapter causing 10x delays).

**Response - Circuit Breaker Pattern**:
When behavioral anomalies are detected, the system implements a resilience strategy:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RESILIENCE EVOLUTION LOOP                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. FAULT INJECTION (10% probability)                                │
│     └─> TimeAdapter.sleep() occasionally takes 10x longer            │
│                                                                     │
│  2. CANARY DETECTION                                                │
│     └─> CanaryTester runs timing consistency checks                 │
│     └─> Measures actual vs expected duration                        │
│     └─> Detects when deviation > threshold (20%)                    │
│                                                                     │
│  3. RESILIENT ADAPTATION                                            │
│     └─> ResilientTimeAdapter wraps raw adapter                      │
│     └─> Tracks cumulative timing drift                              │
│     └─> Compensates by adjusting subsequent sleep durations         │
│     └─> Circuit breaker opens after max_retries failures            │
│                                                                     │
│  4. AUTONOMOUS DECISION                                             │
│     └─> System proposes options in progress.txt                      │
│     └─> Human selects "Option 2: Retry Circuit Breaker"             │
│     └─> System implements ResilientTimeAdapter                      │
│                                                                     │
│  5. VERIFICATION                                                    │
│     └─> Canary tests show improved aggregate behavior               │
│     └─> System maintains 86%+ test coverage                         │
│     └─> verify.sh passes continuously                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Configuration-Driven (Law 3)**:
All resilience thresholds are configured via `src/config/settings.py`:
- `CB_MAX_RETRIES`: Maximum attempts before circuit opens
- `CB_TIMEOUT_SECONDS`: Operation timeout
- `CB_DEVIATION_THRESHOLD_PERCENT`: Acceptable timing variance

**Key Insight**:
The system can detect its own infrastructure instability and autonomously
propose/implement mitigation strategies. This represents a new capability:
"self-protection" - not just self-healing from code issues, but adaptation
to environmental uncertainties.

**Limitation Acknowledged**:
Individual faulty operations still show high deviation. Compensation works
statistically over multiple operations, not per-operation. This is a
fundamental constraint when the fault occurs at the I/O layer.

**Evolution Path**:
Future improvements could include:
- Hardware timing fallback for critical operations
- Predictive fault detection based on system load
- Automatic adapter replacement when faults exceed threshold
