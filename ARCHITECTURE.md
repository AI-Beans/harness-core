# ARCHITECTURE.md - Self-Evolving AI Lab

## System Architecture

### Layered Architecture

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
                               │
                               ▼
                     ┌─────────────────┐
                     │    .harness/    │  ← External tooling (NOT importable by src/)
                     │  verify.sh      │
                     │  feature_list.json│
                     └─────────────────┘
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
│  ├── verify.sh        → CI/CD gate script, runs external to app   │
│  ├── feature_list.json → Task state machine (JSON)               │
│  └── [REFERENCE_PLUGINS] → Language-specific purity checkers     │
│                                                                  │
│  ENFORCEMENT: Project config MUST exclude .harness from src/     │
└──────────────────────────────────────────────────────────────────┘
```

**Rationale**: `.harness/` contains operational tooling. Application code in `src/` must remain pure business logic, testable without running CI/CD scripts.

### Law 2: No Manual Code Writing Philosophy

```
┌──────────────────────────────────────────────────────────────────┐
│  PHILOSOPHY: AI writes all production code                        │
│                                                                  │
│  EXCEPTIONS (allowed for bootstrapping only):                     │
│  1. Placeholder module files                                     │
│  2. config/settings skeleton                                      │
│  3. First test files to define expected behavior                 │
│                                                                  │
│  PROHIBITED:                                                     │
│  ✗ Manual implementation of business logic                       │
│  ✗ Hardcoded values that should be configurable                 │
│  ✗ Comments explaining what code does (code should be self-documenting)│
└──────────────────────────────────────────────────────────────────┘
```

### Law 3: Configuration Management

```
┌──────────────────────────────────────────────────────────────────┐
│  ALL configuration via ONE of:                                   │
│                                                                  │
│  1. Environment Variables (for secrets, deployment-specific)    │
│     → Accessed via config/settings module                         │
│                                                                  │
│  2. config/settings (for defaults, feature flags)               │
│     → Loads from env vars with validation                        │
│     → Type-safe models preferred for validation                  │
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
└── Only: type hints, pure language logic, other domain modules
```

**Reference Plugin**: For Python projects, `check_purity.py` is provided as a reference implementation of domain purity enforcement. Other languages should implement equivalent checks via their own linter plugins.

### Law 5: Telemetry & Observability

Every `verify.sh` execution generates `telemetry.json`:
- Timestamp, task_id
- Linter issues count
- Type checker issues count
- Test pass/fail counts
- Code coverage percentage
- Complexity metrics (files, lines of code)

## Directory Structure

```
[PROJECT_NAME]/
├── src/
│   ├── __init__.[EXT]
│   ├── domain/                    # Pure business logic
│   │   ├── __init__.[EXT]
│   │   └── [entities, services]
│   ├── infrastructure/            # I/O, external integrations
│   │   ├── __init__.[EXT]
│   │   └── logger.[EXT]
│   └── config/                    # Settings loader
│       ├── __init__.[EXT]
│       └── settings.[EXT]
├── tests/
│   ├── __init__.[EXT]
│   ├── test_domain/
│   └── test_infrastructure/
├── .harness/                      # CI/CD tooling (NOT application code)
│   ├── verify.sh                  # Main gate script (language-agnostic template)
│   ├── check_purity.py            # Reference plugin (Python example)
│   └── feature_list.json          # Task state machine
├── config/                        # Configuration files (YAML, TOML, .env.example)
├── docs/
│   ├── PLANS.md
│   └── design-docs/
│       └── core-beliefs.md
├── [PROJECT_CONFIG]
├── AGENTS.md
├── progress.txt
└── telemetry.json
```

## Technology Stack (Template)

| Layer | [LANG_A] | [LANG_B] |
|-------|----------|----------|
| Domain Logic | Pure [LANG_A] | Pure [LANG_B] |
| Testing | [TEST_FRAMEWORK_A] | [TEST_FRAMEWORK_B] |
| Linting | [LINTER_A] | [LINTER_B] |
| Type Checking | [TYPE_CHECKER_A] | [TYPE_CHECKER_B] |
| Config | [CONFIG_LIB_A] | [CONFIG_LIB_B] |
| Logging | JSON structured | structured |

## Enforcement

1. **CI/CD Gate** (verify.sh):
   - [YOUR_LINTER] → MUST pass
   - [YOUR_TYPE_CHECKER] → MUST pass
   - [YOUR_TEST_RUNNER] coverage threshold → MUST pass
   - Auto-commit on success

2. **Import Boundaries**:
   - [TYPE_CHECKER] enforces no infrastructure imports in domain
   - [LINTER] checks import order (stdlib → third-party → local)

3. **Coverage Gate**:
   - [COVERAGE_THRESHOLD]% minimum line coverage
   - 100% coverage for domain layer (ideal target)

## Reference Plugin Note

The `check_purity.py` file in `.harness/` is a **reference implementation** for Python projects demonstrating Law 4 (Domain Purity) enforcement. It is NOT meant to be run directly by non-Python projects.

For non-Python languages, implement equivalent domain purity checks using:
- ESLint rules for TypeScript/JavaScript
- Custom linter plugins for other languages
- IDE/editor static analysis configurations
