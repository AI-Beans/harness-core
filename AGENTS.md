# Self-Evolving AI Lab

A fully autonomous coding agent system where AI writes, tests, and evolves code with zero human intervention.

## Quick Navigation

| Purpose | Path |
|---------|------|
| **System Architecture (5 Laws)** | `docs/ARCHITECTURE.md` |
| **Core Beliefs** | `docs/design-docs/core-beliefs.md` |
| **Development Plans** | `docs/PLANS.md` |
| **Task Progress** | `docs/exec-plans/progress.txt` |
| **Feature Backlog** | `docs/exec-plans/feature_list.json` |
| **Quality Metrics** | `docs/QUALITY_SCORE.md` |
| **Reliability Docs** | `docs/RELIABILITY.md` |
| **Toolchain References** | `docs/references/` |

## Project Structure

```
./
├── AGENTS.md              # This file - entry point & index
├── ARCHITECTURE.md        # System architecture (5 Laws)
├── telemetry.json         # Real-time metrics
├── src/
│   ├── domain/          # Pure business logic (Law 4)
│   ├── infrastructure/   # I/O, adapters
│   └── config/          # Settings (Law 3)
├── tests/                # Test files
├── docs/                # Documentation
│   ├── ARCHITECTURE.md  # 5 Architecture Laws
│   ├── PLANS.md         # Development roadmap
│   ├── QUALITY_SCORE.md # Quality metrics
│   ├── RELIABILITY.md   # Resilience metrics
│   ├── design-docs/     # Design documentation
│   ├── exec-plans/      # Execution tracking
│   └── references/      # Toolchain specs (future)
└── .harness/           # CI/CD tooling
    └── verify.sh        # Verification gate (language-agnostic template)
```

## Verification

```bash
# Run verification (auto-commits on success)
bash .harness/verify.sh

# Current status: all 5 Laws passing
```

## Architecture Laws

| Law | Description | Status |
|-----|-------------|--------|
| Law 1 | src/ vs .harness/ Isolation | ✓ COMPLIANT |
| Law 2 | No Manual Code Writing | ✓ COMPLIANT |
| Law 3 | Configuration Management | ✓ COMPLIANT |
| Law 4 | Domain Purity | ✓ COMPLIANT |
| Law 5 | Telemetry & Observability | ⚠ PARTIAL |

## Development Workflow

1. **Task Planning**: See `docs/exec-plans/feature_list.json`
2. **Implementation**: Follow 5 Architecture Laws
3. **Verification**: Run `bash .harness/verify.sh`
4. **Progress**: Tracked in `docs/exec-plans/progress.txt`

---

## Agent Guidelines

### Available Tools

Your project should specify its language runtime and package manager in its own configuration.

### Build/Lint/Test Commands

Customize for your language stack:

```bash
# [YOUR_LANGUAGE] - Example for Python
[YOUR_LINTER] check .
[YOUR_TYPE_CHECKER] src/
[YOUR_TEST_RUNNER] tests/ -v --cov=src

# Verify (full gate)
bash .harness/verify.sh
```

### Code Style

Customize for your language conventions:

```bash
# Example: Configure in your project's linting config
[YOUR_LINTER] --config [YOUR_LINTER_CONFIG]
```

### Error Handling

- Always handle errors explicitly
- Use specific error types
- Never swallow exceptions silently
