# Mutation Testing Tool Installation Patterns

On-demand installation conventions for language-specific mutation testing tools. The `mutation-testing` skill uses these patterns to detect, install, and configure tools per project language.

## Pattern: Detect → Check → Ask → Install → Cache

For each language, the skill follows this sequence:

1. **Detect** language from project files (see table below)
2. **Check** if the tool binary exists (`command -v <tool>` or `npx <tool> --version`)
3. **Ask** user for permission to install if missing
4. **Install** using the project's package manager
5. **Cache** installation status (avoid re-checking within session)

## Tool Reference

### JavaScript / TypeScript → Stryker

**Detection:** `package.json` exists AND (`*.ts` or `*.js` files present)

**Check:** `npx stryker --version` (project-local) or `command -v stryker` (global)

**Install:**
```bash
# Initialize Stryker in the project (interactive — asks about test runner)
npx stryker init

# Or non-interactive with defaults:
npm install -D @stryker-mutator/core @stryker-mutator/jest-runner @stryker-mutator/typescript-checker
```

**Key flags for diff-scoped runs:**
```bash
npx stryker run --mutate "src/utils.ts:10-35" --reporters json,progress --incremental
```

**Output:** `reports/mutation/mutation.json` (mutation-testing-elements standard schema)

---

### Python → mutmut

**Detection:** `pyproject.toml`, `setup.py`, or `setup.cfg` exists

**Check:** `command -v mutmut` or `python -m mutmut --version`

**Install:**
```bash
pip install mutmut
# or
pipx install mutmut
```

**Key flags for scoped runs:**
```bash
mutmut run --paths-to-mutate src/utils.py
```

**Output:** Results in `.mutmut-cache` SQLite database. Query with `mutmut results` and `mutmut show <id>`.

**Note:** mutmut targets files, not lines. The skill filters results post-hoc to show only mutations within the diff range.

---

### Rust → cargo-mutants

**Detection:** `Cargo.toml` exists

**Check:** `command -v cargo-mutants` or `cargo mutants --version`

**Install:**
```bash
cargo install cargo-mutants
```

**Key flags for diff-scoped runs:**
```bash
# Diff-based (best for interactive use)
cargo mutants --in-diff <(git diff HEAD~1) --json

# Function-targeted
cargo mutants --function "parse_config" --json

# File-targeted
cargo mutants --file src/utils.rs --json

# Dry run (list mutants without executing)
cargo mutants --list --json
```

**Output:** `mutants.out/outcomes.json` with per-mutant test results.

---

### Java / Kotlin → PIT (pitest)

**Detection:** `pom.xml` (Maven) or `build.gradle` / `build.gradle.kts` (Gradle)

**Check:** Check if PIT plugin is configured in the build file

**Install (Maven):** Add to `pom.xml` plugins section:
```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.19.1</version>
    <dependencies>
        <dependency>
            <groupId>org.pitest</groupId>
            <artifactId>pitest-junit5-plugin</artifactId>
            <version>1.2.1</version>
        </dependency>
    </dependencies>
</plugin>
```

**Install (Gradle):** Add to `build.gradle`:
```groovy
plugins {
    id 'info.solidsoft.pitest' version '1.15.0'
}

pitest {
    junit5PluginVersion = '1.2.1'
    outputFormats = ['XML', 'HTML']
}
```

**Key flags for scoped runs:**
```bash
# Maven — target specific classes
mvn pitest:mutationCoverage -DtargetClasses="com.example.Utils" -DoutputFormats=XML -Dthreads=4

# Maven — SCM-aware (only changed code)
mvn pitest:scmMutationCoverage -DoutputFormats=XML

# Gradle
./gradlew pitest -Dpitest.targetClasses="com.example.Utils"
```

**Output:** `target/pit-reports/YYYYMMDDHHMI/mutations.xml`

---

### Go → gremlins

**Detection:** `go.mod` exists

**Check:** `command -v gremlins`

**Install:**
```bash
go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
```

**Key flags:**
```bash
gremlins unleash --tags "src/utils.go"
```

**Output:** Text-based (limited programmatic output).

**Warning:** gremlins is pre-1.0 and may not work well on large Go modules. Present a low-confidence warning to the user when this tool is selected.

---
