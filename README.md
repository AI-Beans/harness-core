# harness-core

> **The Agent-Native Workspace Framework**
>
> Based on OpenAI 2026's *System of Record* & *Mechanical Taste* paradigms.

---

## What is harness-core?

harness-core is the **extracted OS (Operating System) layer** of a self-evolving AI development system. It provides the foundational infrastructure for building **Agent-Native workspaces** — environments where AI agents can autonomously write, test, verify, and evolve code with zero human intervention.

Think of it as the **kernel** for your AI development pipeline. It doesn't care *what* you build — it only cares *how* you build it: with rigor, observability, and autonomous quality enforcement.

---

## Core Philosophy

### The 5 Laws of harness-core

| Law | Name | Description |
|-----|------|-------------|
| **Law 1** | Physical Isolation | `.harness/` is NOT application code — it's the OS layer |
| **Law 2** | No Manual Code Writing | AI writes all production code; humans don't touch business logic |
| **Law 3** | Configuration as DNA | All behavior externalized to `config/` — no magic constants |
| **Law 4** | Domain Purity | `src/domain/` is pure business logic — zero I/O, zero infrastructure deps |
| **Law 5** | Telemetry & Observability | Every verification run emits metrics; nothing is silent |

### The System of Record

Inspired by OpenAI 2026's concept, harness-core treats **verification as ground truth**:

```
Code → Verify → Telemetry → Decision → Evolution
```

The `.harness/verify.sh` script is the **system of record**. It:
1. Runs linting ([YOUR_LINTER])
2. Runs type checking ([YOUR_TYPE_CHECKER])
3. Enforces domain purity (via language-specific plugin)
4. Runs tests with coverage ([YOUR_TEST_RUNNER])
5. Emits `telemetry.json` — the single source of truth for system health

### Mechanical Taste

harness-core acknowledges that **not everything can be enforced by tools**. The concept of *Mechanical Taste* represents the gap between what machines can verify and what AI agents must self-regulate:

- Tooling can catch unused imports, but not *semantic* imports in domain layer
- Tooling can measure coverage, but not *meaningful* coverage
- Tooling can run tests, but not judge if tests are well-designed

**Mechanical Taste** is the AI exercising judgment in areas tools cannot reach.

---

## Directory Structure

```
harness-core/
├── .harness/              # The OS layer (DO NOT import from src/)
│   ├── verify.sh          # Verification gate + telemetry emitter (template)
│   └── check_purity.py    # Reference Plugin (Python example for Law 4)
├── docs/
│   ├── ARCHITECTURE.md     # System architecture documentation
│   ├── PLANS.md           # Development roadmap template
│   ├── QUALITY_SCORE.md   # Quality metrics and thresholds
│   ├── RELIABILITY.md     # Resilience and fault-tolerance patterns
│   ├── design-docs/
│   │   └── core-beliefs.md # The 9 Core Beliefs + Mechanical Taste
│   ├── exec-plans/
│   │   ├── progress.txt   # TEMPLATE: Activity log
│   │   └── feature_list.json  # TEMPLATE: Task backlog
│   └── references/       # Toolchain specifications (future)
└── AGENTS.md              # Agent guidelines and command reference
```

---

## Quick Start

### 1. Bootstrap a new project

```bash
# Create your project directory
mkdir my-agent-workspace && cd my-agent-workspace

# Copy the harness-core OS layer
cp -r /path/to/harness-core/.harness .
cp -r /path/to/harness-core/docs .

# Copy constitution files
cp /path/to/harness-core/AGENTS.md .
cp /path/to/harness-core/docs/ARCHITECTURE.md .
```

### 2. Initialize your language stack

**Python:**
```bash
uv init --src src --tests tests
uv add [YOUR_LINTER] [YOUR_TYPE_CHECKER] [YOUR_TEST_RUNNER] [COVERAGE_TOOL]
```

**Node.js/TypeScript:**
```bash
npm init
npm install --save-dev [YOUR_LINTER] [YOUR_TYPE_CHECKER] [YOUR_TEST_RUNNER]
```

**Go:**
```bash
go mod init my-project
go get [LINTER] [TYPE_CHECKER] [TEST_FRAMEWORK]
```

### 3. Configure your verification gate

Edit `.harness/verify.sh` to match your stack. Replace the placeholder regions:

```bash
# ==== LINTER SECTION ====
LINTER_OUTPUT=$([YOUR_LINTER] . 2>&1)

# ==== TYPE CHECKER SECTION ====
TYPECHECK_OUTPUT=$([YOUR_TYPE_CHECKER] 2>&1)

# ==== TEST RUNNER SECTION ====
TEST_OUTPUT=$([YOUR_TEST_RUNNER] --coverage 2>&1)
```

### 4. Implement Domain Purity Check (Law 4)

**For Python projects:** Uncomment the domain purity section in `verify.sh` and use `check_purity.py`.

**For other languages:** Implement equivalent enforcement via your linter:
- TypeScript/ESLint: Write a custom rule for `no-restricted-imports` in domain
- Go: Use a custom linter plugin
- Rust: Use clippy restrictions

### 5. Initialize git and start the loop

```bash
git init
git config user.name "agent"
git config user.email "agent@your-workspace.ai"
bash .harness/verify.sh
```

If all checks pass → you get an automatic commit with telemetry.

---

## The Autonomous Loop

Once bootstrapped, your workspace runs this loop:

```
┌─────────────────────────────────────────────────────────────┐
│                     AUTONOMOUS LOOP                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   1. TASK IDENTIFICATION                                    │
│      └─ Agent reads feature_list.json, selects next task    │
│                                                             │
│   2. CODE GENERATION                                        │
│      └─ AI writes production code in src/                   │
│      └─ AI writes tests in tests/                           │
│                                                             │
│   3. VERIFICATION (verify.sh)                                │
│      └─ [YOUR_LINTER]: 0 issues                             │
│      └─ [YOUR_TYPE_CHECKER]: 0 issues                       │
│      └─ [YOUR_TEST_RUNNER]: all pass, coverage ≥ threshold │
│      └─ Domain purity: enforced (via language plugin)       │
│                                                             │
│   4. TELEMETRY                                              │
│      └─ telemetry.json updated with run metrics             │
│      └─ Progress logged to progress.txt                     │
│                                                             │
│   5. DECISION                                                │
│      └─ If all green → auto-commit                         │
│      └─ If failures → analyze, fix, retry                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## The 9 Core Beliefs

1. **Autonomy First** — No human in the loop
2. **Verification Before Creation** — Gates before merge
3. **Fail Fast, Recover Faster** — Detect, log, adapt
4. **Everything is Trackable** — No silent changes
5. **Incremental Evolution** — Atomic, verifiable tasks
6. **Language-Agnostic Core** — Right tool for the job
7. **Zero Tolerance for Code Pollution** — Strict standards
8. **Mechanical Taste** — Self-regulation beyond tooling
9. **Resilience Evolution** — Adapt to environmental uncertainty

---

## Quality Gates (Template)

| Gate | Tool | Threshold |
|------|------|-----------|
| Linting | [YOUR_LINTER] | 0 issues |
| Type Checking | [YOUR_TYPE_CHECKER] | 0 issues |
| Domain Purity | [LANGUAGE_PLUGIN] | pass |
| Test Coverage | [YOUR_TEST_RUNNER] | ≥ [THRESHOLD]% |
| All Tests | [YOUR_TEST_RUNNER] | 100% pass |

---

## Telemetry Schema

Every `verify.sh` run emits `telemetry.json`:

```json
{
  "timestamp": "2026-03-31T12:00:00Z",
  "task_id": "task-001",
  "metrics": {
    "linter": { "issues": 0, "tool": "[YOUR_LINTER]" },
    "type_checker": { "issues": 0, "tool": "[YOUR_TYPE_CHECKER]" },
    "domain_purity": { "issues": 0 },
    "coverage": { "percentage": 91.5, "threshold": 80 },
    "tests": { "passed": 62, "failed": 0 }
  },
  "complexity": { "src_files": 31, "total_lines": 1459 }
}
```

This becomes your **system of record** — the truth about your codebase's health.

---

## Reference Plugin: check_purity.py

`.harness/check_purity.py` is provided as a **reference implementation** demonstrating Law 4 (Domain Purity) enforcement for Python projects. It parses Python AST to ensure `src/domain/` imports only stdlib modules.

**For non-Python projects:** Implement equivalent domain purity checks using your language's linter plugin system. The principle remains constant: domain layer must contain zero imports from infrastructure or config layers.

---

## Extending harness-core

### Adding a new language

1. Update `.harness/verify.sh` with the new linter/type-checker/test runner
2. Implement domain purity enforcement via linter plugin
3. Document in `docs/references/`

### Custom quality metrics

1. Edit `docs/QUALITY_SCORE.md` with new thresholds
2. Update `.harness/verify.sh` to emit new metrics
3. Add to `telemetry.json` schema

### Resilience patterns

See `docs/RELIABILITY.md` for circuit breaker patterns and fault injection strategies.

---

## The Seed

harness-core is designed to be **cloned, not referenced**. It is the **seed** from which new agent-native workspaces germinate.

```
git clone <your-harness-core-fork>
cp -r harness-core/.harness your-new-project/
cp -r harness-core/docs your-new-project/
# ... customize for your domain ...
bash your-new-project/.harness/verify.sh
```

Every workspace is independent, but all share the same **OS layer** — the unchanging foundation of autonomous development.

---

## License

MIT — Clone freely, evolve relentlessly.

---

**"The best infrastructure is the one you never have to think about."**
