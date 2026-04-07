---
name: mutation-testing
description: >
  Diff-scoped mutation testing to verify test quality beyond coverage metrics. Detects language, selects the appropriate tool (Stryker, mutmut, cargo-mutants, PIT, gremlins), and runs mutations only on changed code. Use when asked to run mutation testing, check test quality, find weak tests, verify test coverage is meaningful, or "are my tests actually catching bugs?". Also use after TDD cycle completes or when bugmagnet identifies test coverage gaps. Triggers on: mutation testing, mutant, test quality, weak tests, test effectiveness, "do my tests catch bugs", "are these tests good enough", "verify test quality", "mutation score".
---

# Mutation Testing

Diff-scoped mutation testing: systematically verify that your tests catch real bugs by introducing small code changes (mutations) and checking if the test suite detects them.

**Always diff-scoped.** Full-project mutation testing is impractical interactively. This skill scopes to changed code by default.

## Phase 1: Language Detection & Tool Selection

Detect the project language and select the mutation testing tool.

| Project File | Language | Tool | Interactive Viability |
|-------------|----------|------|----------------------|
| `package.json` + `*.ts`/`*.js` | JavaScript/TypeScript | Stryker | High — line-range targeting, incremental mode |
| `pyproject.toml` / `setup.py` | Python | mutmut | Medium — file-level targeting only |
| `Cargo.toml` | Rust | cargo-mutants | High — `--in-diff` flag, function targeting |
| `pom.xml` / `build.gradle` | Java/Kotlin | PIT | Medium — class-level targeting |
| `go.mod` | Go | gremlins | Low — pre-1.0, limited targeting |

**If multiple languages detected:** ask the user which to target.
**If no supported language:** STOP: "No mutation testing tool available for this project's language."
**If Go detected:** warn: "Go mutation testing uses gremlins (pre-1.0). Results may be limited."

## Phase 2: Tool Installation Check

Check if the selected tool is installed. If not, offer to install.

Refer to [references/tool-install-patterns.md](references/tool-install-patterns.md) for per-language install commands.

1. Check if tool exists:
   - Stryker: `npx stryker --version` (project-local preferred)
   - mutmut: `command -v mutmut`
   - cargo-mutants: `command -v cargo-mutants`
   - PIT: check `pom.xml`/`build.gradle` for pitest plugin
   - gremlins: `command -v gremlins`

2. If missing → ask user:
   ```
   <tool> not found. Install it?
   Y) Install now (<install command>)
   N) Skip mutation testing
   ```

3. Install using the commands in the references doc.

## Phase 3: Scope Determination

Determine which code to mutate. Always prefer the narrowest scope.

**Scope resolution (priority order):**
1. User-specified files/functions → use directly
2. Staged changes → `git diff --cached --name-only` + line ranges from `git diff --cached`
3. Unstaged changes → `git diff --name-only` + line ranges from `git diff`
4. Recent commit → `git diff HEAD~1 --name-only` + line ranges from `git diff HEAD~1`
5. No changes → ask: "No recent changes detected. Which files should I target?"

**Extract file paths and line ranges from the diff:**
```bash
# Get changed files (filter to source code, exclude tests)
git diff --name-only | grep -v -E '(test|spec|__test__)' | head -20

# Get line ranges per file
git diff --unified=0 <file> | grep '^@@' | sed -E 's/.*\+([0-9]+)(,([0-9]+))?.*/\1-\1+\3/'
```

Report: "Targeting 3 changed files: src/utils.ts (lines 10-35), src/pricing.ts (lines 40-55), src/auth.ts (lines 12-28)"

## Phase 4: Dry Run & Speed Check

Before running, estimate the work and warn if it will be slow.

**Per-tool dry run:**
- Stryker: `npx stryker run --mutate "<file>:<lines>" --dryRun` (parse output for mutant count)
- cargo-mutants: `cargo mutants --in-diff <(git diff) --list --json | jq length`
- mutmut: estimate ~1 mutant per 3 lines of code in the targeted file
- PIT: estimate from class size (~1 mutant per 5 lines)

**Speed guardrails:**
- If mutant count <= 50 → proceed automatically
- If mutant count > 50 → warn:
  ```
  ~85 mutants detected. Estimated time: 5-10 minutes.
  A) Run all
  B) Narrow scope — specify a function or line range
  C) Cancel
  ```

## Phase 5: Run Mutations

Execute the mutation testing tool with appropriate flags.

**Stryker (JS/TS):**
```bash
npx stryker run \
  --mutate "src/utils.ts:10-35" \
  --reporters json,progress \
  --incremental \
  --incrementalFile .stryker-incremental.json \
  --concurrency $(( $(nproc 2>/dev/null || sysctl -n hw.ncpu) - 1 ))
```
Output: `reports/mutation/mutation.json`

**mutmut (Python):**
```bash
mutmut run --paths-to-mutate src/utils.py
mutmut results
mutmut show all
```
Output: `.mutmut-cache` SQLite database

**cargo-mutants (Rust):**
```bash
cargo mutants \
  --in-diff <(git diff HEAD~1) \
  --json \
  --baseline=skip \
  -j $(( $(nproc 2>/dev/null || sysctl -n hw.ncpu) ))
```
Output: `mutants.out/outcomes.json`

**PIT (Java — Maven):**
```bash
mvn pitest:mutationCoverage \
  -DtargetClasses="com.example.Utils" \
  -DoutputFormats=XML \
  -Dthreads=$(( $(nproc 2>/dev/null || sysctl -n hw.ncpu) )) \
  -DhistoryInputLocation=target/pit-history.bin \
  -DhistoryOutputLocation=target/pit-history.bin
```
Output: `target/pit-reports/*/mutations.xml`

**gremlins (Go):**
```bash
gremlins unleash --tags "src/utils.go"
```
Output: text to stdout

## Phase 6: Parse & Present Results

Parse the tool output and categorize each mutant.

**Mutant categories:**
- **Killed** — test suite caught the mutation (good)
- **Survived** — test suite missed it (action needed)
- **No Coverage** — no test runs this code (action needed)
- **Timeout** — test timed out (usually means an infinite loop mutation — effectively killed)
- **CompileError** — mutation caused compilation failure (not actionable)

**For mutmut:** filter results to only show mutations within the diff line range (mutmut targets whole files).

**Present summary first:**
```
Mutation Score: 78% (45/58 killed, 10 survived, 3 no coverage)
```

**Then present each surviving mutant with a fix suggestion:**
```
SURVIVING MUTANTS (tests didn't catch these):

[SURVIVED] ConditionalBoundary — src/utils.ts:24
  Mutation: changed `age >= 18` → `age > 18`
  Why it matters: Edge case at exact boundary value (age=18) is not tested
  Suggested test:
    expect(isAdult(18)).toBe(true)   // boundary: exactly 18
    expect(isAdult(17)).toBe(false)  // just below boundary

[SURVIVED] ArithmeticOperator — src/pricing.ts:42
  Mutation: changed `price * quantity` → `price / quantity`
  Why it matters: Core business logic — no test verifies the actual calculation result
  Suggested test:
    expect(calculateTotal(10, 3)).toBe(30)  // verify multiplication, not just non-null

[NO COVERAGE] — src/auth.ts:20-28
  Function `validateToken` has no test coverage
  Suggested: Add test verifying token validation returns true for valid tokens
  and false/throws for expired, malformed, or missing tokens
```

## Phase 7: Summary

```
MUTATION TESTING SUMMARY

Tool: Stryker (JS/TS)
Scope: 3 files, 58 mutants (diff-scoped)
Score: 78% (45 killed, 10 survived, 3 no coverage)

Test improvements needed:
  1. Add boundary value tests for age/date comparisons (3 surviving mutants)
  2. Assert exact calculation results, not just non-null (4 surviving mutants)
  3. Add tests for validateToken function (3 no-coverage mutants)

Re-run after adding tests to verify improvement.
```

## Integration with Other Skills

- **After `superpowers:test-driven-development`**: Validates that TDD tests are strong, not just green
- **After `bugmagnet`**: Quantifies how weak the tests are when bugmagnet identifies gaps
- **With `ct:fix-loop`**: Optional verification — after fixing review findings, run mutations on changed code

## Limitations

- **Always diff-scoped** — will not run full-project mutation testing (too slow). Specify files/functions for broader scope.
- **Go support is weak** — gremlins is pre-1.0 and limited.
- **mutmut targets files, not lines** — results are filtered post-hoc to the diff range.
- **PIT requires Maven/Gradle** — standalone Java projects without a build tool are not supported.
- **First run is slower** — subsequent runs benefit from incremental caching (Stryker, PIT).
