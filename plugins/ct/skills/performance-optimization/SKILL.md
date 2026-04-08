---
name: performance-optimization
description: >
  Use when optimizing backend, API, database, or system performance. Also use when
  response times are slow, queries need tuning, throughput is degraded, or someone says
  "just add caching." Triggers on: optimize API, backend slow, API latency, database
  performance, query optimization, server response time, connection pooling, N+1 queries,
  cache strategy, load testing. For frontend/UI performance (Core Web Vitals, Lighthouse
  accessibility), use frontend-production-quality instead.
---

# Performance Optimization

## The Iron Law

HARD GATE - Baseline Requirement:
→ Performance optimization task started → Do I have a recorded baseline metric (number + tool + conditions)?
  No → STOP.
    Has code already been changed?
      Yes → Git stash changes, measure old code, re-apply, measure again.
      No → Measure baseline NOW before any changes.
  Yes → Proceed to profiling.

No optimization without baseline measurement. No exceptions. Violating the letter of this process IS violating the spirit.

---

## MANDATORY FIRST STEP

**TodoWrite:** Create items for each phase below.

**Never skip measurement:**
- 70% of "obvious" bottlenecks are wrong — Profile first
- 40% of optimizations without baseline cause regressions
- Production monitoring dashboards are NOT a substitute for a controlled baseline

---

## Process: BASELINE → PROFILE → STRATEGY → IMPLEMENT → VALIDATE

### 1. Baseline Measurement (BEFORE any code changes)

Record **tool + metric + value + conditions** (e.g., "k6 load test: p95 = 4.2s at 100 req/s, dataset: 10k rows"). Must be reproducible — `curl` wall-clock time is NOT a baseline. Use load testing tools (k6, wrk, vegeta) for APIs, `EXPLAIN ANALYZE`/`pg_stat_statements` for databases, APM traces for applications.

### 2. Bottleneck Analysis (PROFILE, don't guess)

- Profile with appropriate tool (see above)
- Identify slowest operation with **specific timing and % of total**
  - e.g., "orders query = 3.1s, 78% of total request time"
- Determine root cause (N+1 queries, missing index, blocking I/O, serialization)

→ Profiling complete → Does result match initial assumption?
  No → Am I tempted to trust my assumption over the data? → STOP. Trust the profiler. Implement based on profiling data, not assumption.
  Yes → Implement based on profiling.

### 3. Optimize and Validate

- Evaluate 2-3 approaches with tradeoffs. State expected improvement.
- Implement minimal change — fix the measured bottleneck only
- **Re-measure with same tool, same conditions** as step 1
- Compare before/after with specific numbers. Check no regressions.
- Record results in PR description with tool, conditions, and numbers

---

## Red Flags — STOP If You Think Any of These

| Thought | Reality |
|---------|---------|
| "Bottleneck is obvious, skip profiling" | 70% wrong without data. Profile first. |
| "We'll measure after" | Can't validate without before. Measure NOW. |
| "Manual testing / curl is enough" | Need reproducible metrics, not feelings. |
| "Production dashboards = baseline" | Different conditions, not controlled. Measure directly. |
| "Senior dev says cache everything" | That's a hypothesis, not a diagnosis. Profile first. |
| "Already changed the code, too late" | Roll back, measure old code, re-apply, measure again. |
| "No time to profile" | 15 min profiling saves hours of wrong-direction work. |
| "I've seen this pattern before" | This system is different. Measure THIS system. |

---

## What To Do When You Skipped Baseline

If you already made changes without measuring:

1. **Do NOT rationalize retroactive baselines** (production dashboards, "estimates")
2. **Git stash or branch** your changes
3. **Measure the old code** with proper tooling under controlled conditions
4. **Re-apply your changes**
5. **Measure again** with identical tool + conditions
6. **Now** you have a valid before/after comparison

This costs 30-60 minutes. Shipping unvalidated "performance improvements" costs trust, debugging time, and potential regressions.
