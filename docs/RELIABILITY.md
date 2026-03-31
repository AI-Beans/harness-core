# Reliability Codex

This document defines reliability and resilience metrics for the Self-Evolving AI Lab system.

## Resilience Architecture

### Fault Tolerance Levels

| Level | Description | Failure Rate |
|-------|-------------|--------------|
| L1 - Basic | TimeAdapter without protection | 10% deviation |
| L2 - Resilient | ResilientTimeAdapter with retry | < 1% effective |
| L3 - Adaptive | Circuit breaker + drift compensation | < 0.1% effective |

### Canary Test Metrics

| Test | Threshold | Behavior |
|------|-----------|----------|
| Timing Consistency | CV < 20% | Measures sleep accuracy |
| Determinism | CV < 20% | Measures operation variance |

## Circuit Breaker States

```
       ┌─────────────────────────────────────┐
       │                                     │
       ▼                                     │
   ┌───────┐    failures >= max    ┌──────┐
   │ CLOSED │ ──────────────────► │ OPEN │
   └───────┘                       └──────┘
       ▲                                 │
       │     successes > threshold         │
       │                                 │
   ┌───────┐                       ┌──────┐
   │HALF_OPEN│◄──────────────────── │      │
   └───────┘                       └──────┘
```

### State Transitions

| From | To | Trigger |
|------|-----|---------|
| CLOSED | OPEN | `consecutive_failures >= max_retries` |
| OPEN | HALF_OPEN | `recovery_timeout` elapsed |
| HALF_OPEN | CLOSED | `success` |
| HALF_OPEN | OPEN | `failure` |

## Drift Compensation

The `DriftCompensator` tracks timing drift and adjusts future sleep durations:

```
target = requested - cumulative_drift
```

### Compensation Rules

1. On anomaly (actual > requested * 1.2):
   - `drift += (actual - requested) * 0.8`
   - Cap drift at `requested * 0.8`

2. On success (actual >= requested * 0.9):
   - `drift *= 0.9` (gradual recovery)

3. On under-run (actual < requested * 0.9):
   - `drift -= 0.001` (small correction)

## Failure Budget

| Component | Max Failures/Day | Alert Threshold |
|-----------|-----------------|-----------------|
| TimeAdapter | 10 | 7 |
| ResilientTimeAdapter | 2 | 1 |
| Circuit Breaker | 1 | 0 |

## Recovery Metrics

| Metric | Target | Critical |
|--------|--------|----------|
| MTTR (Mean Time To Recovery) | < 5 min | > 15 min |
| MTTD (Mean Time To Detect) | < 30 sec | > 2 min |
| Availability | ≥ 99.9% | < 99% |

## Resilience Evolution History

| Date | Task | Change |
|------|------|--------|
| 2026-03-31 | Task-016 | Added fault injection (10% probability) |
| 2026-03-31 | Task-017 | Implemented ResilientTimeAdapter |
| 2026-03-31 | Task-020 | Split modules, improved maintainability |
