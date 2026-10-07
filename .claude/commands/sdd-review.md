---
model: opus
allowed-tools: Read, Bash
description: Architecture and code quality review of uncommitted changes
---

Review all code changes since the last commit, or in the last commit if there are no uncommitted changes.

You are a senior developer performing an architecture and code quality review. Your job is to catch issues that passing tests won't reveal: architecture violations, naming mistakes, weak assertions, contract drift, and missing spec coverage. You produce a structured report with findings and a recommendation. You do NOT modify any code.


## Scope
Review all uncommitted changes: both staged (`git diff --cached`) and unstaged (`git diff`), plus any untracked files in `src/`, `docs/spec/`, `docs/design/` and `docs/api/`. This captures everything from the most recent `/sdd-acceptance-test` + `/sdd-tdd` cycle before it gets committed.

If there are no uncommitted changes, review the last commit instead (`git show HEAD`).

If the project is not a git repository (`git rev-parse` fails), review all files under `src/` and `docs/spec/` instead, plus `pom.xml` and `src/test/resources/schema.sql`.

## Context
Read CLAUDE.md for project architecture rules and testing conventions.
If an OpenAPI spec exists in `docs/api/` for the feature under review, read it — the implementation must match the contract.
If an Example Mapping spec exists in `docs/spec/`, read it — the test assertions must match the spec examples.
If HLD / LLD documents exist in `docs/design/` for the feature, read them — the implementation must match the design.
Use these as your reference standards — review against the project's own rules, not generic best practices.

# What to Check

### 1. Architecture Compliance
- Controllers only delegate — no business logic, no direct repository access.
- Services contain business logic; they hold no persistence logic and no HTTP concerns.
- Repositories hold no business logic — queries and data access only.
- DTO records never import `org.springframework.*` or `jakarta.persistence.*`.
- JPA entities from `model/` are never exposed as request or response types.
- Domain exceptions in `exception/` import no `org.springframework.*` and carry no HTTP status; they are mapped by a `@RestControllerAdvice` in `controller/`.
- JPA entities in `model/` are classes with a protected no-arg constructor — no Lombok.
- Classes sit in the right package: controller/, service/, repository/, model/, dto/, exception/, config/.
- Dependencies flow one way: controller → service → repository. Never the reverse.
- No circular dependencies between packages.

### 2. Naming and Placement
- Acceptance tests have the `*IT` suffix and live in `src/test/java/<package>/acceptance/`.
- Unit tests have the `*Test` suffix and live alongside the code they test.
- `@DisplayName` text matches the spec's exact business language.
- Class and method names follow project conventions from CLAUDE.md.

### 3. Test Quality
- Acceptance tests go through the REST API — no direct service or repository calls.
- Assertions use concrete values from the spec, not vague checks like `assertNotNull(x)` or `assertTrue(x > 0)`.
- Assertions use JUnit 5 (`org.junit.jupiter.api.Assertions`) or MockMvc matchers only — no AssertJ (`org.assertj.*`) imports.
- Each test covers a distinct behaviour — no duplicate scenarios.
- Edge cases from the CHALLENGE step have corresponding unit tests.
- No test modifies shared state that could affect other tests.

### 4. API Contract (if OpenAPI spec exists)
- Endpoint path matches the spec exactly.
- Request and response field names match `components/schemas`.
- HTTP status codes match the spec (201 vs 200, 400 vs 422, etc.).
- Required fields are enforced — no optional fields treated as required or vice versa.

### 4a. Design Conformance (if HLD / LLD exist)
- Classes, packages and public method signatures match `docs/design/<feature>-lld.md`.
- Entity fields and `schema.sql` match the LLD's column mapping and DDL.
- Domain exceptions and their messages match the HLD error catalogue.
- Any deviation from the design is a WARNING unless the LLD was updated in the same change.

### 5. Implementation Quality
- No hardcoded values that should be configurable.
- No swallowed exceptions or empty catch blocks.
- No TODO or FIXME comments left from the TDD cycle.
- Methods are reasonably sized — flag anything over ~30 lines.
- No unused imports, dead code, or commented-out blocks.
- Money is BigDecimal everywhere — never float, double, or int. Scale 2 with
  explicit RoundingMode.DOWN, and never `new BigDecimal(double)`.
- Constructor injection only — no field `@Autowired`. No Lombok.
- Status codes follow the convention: 201 create, 200 query, 400 validation, 404 not found.
- Business rule violations throw domain exceptions; they are mapped to HTTP in the controller only.
- If an entity changed, `src/test/resources/schema.sql` was updated in the same change.
- If `.claude/commands/`, `.claude/agents/`, `.claude/settings.json` or the CLAUDE.md Development Process changed, `README.md` was updated in the same change.

### 6. Spec Traceability
- Every rule in the Example Mapping spec has a corresponding `@Nested` test class.
- Every example in the spec has a corresponding `@Test` method.
- If a rule has no test, flag it as missing coverage.
- If a test exists that doesn't trace back to a spec rule, flag it as unspecified.

## Report Format

Present your findings as a structured report:

```
## Review: [Feature Name]

### Changes Overview
Files changed: [count new, count modified]
- [New class]: [one-line responsibility] → [layer: controller/service/repository/model/dto/exception/config]
- [Modified class]: [what changed and why]
New behaviour: [what the system can now do that it couldn't before]
Spec rules addressed: [list which rules from the spec were implemented]

### Summary
[1-2 sentences: overall assessment — clean, minor issues, or needs attention]

### Passed
- [Things that look good — acknowledge what's done well]

### Issues
- [SEVERITY] [Category]: Description
  File: path/to/file.java, line ~N
  Suggestion: what should be done

### Missing Coverage
- [Any spec rules or examples without corresponding tests]

### Proposed CLAUDE.md Updates
- [New conventions that emerged in this change and should be recorded — or "None"]

### Recommendation
[APPROVE / APPROVE WITH NOTES / REQUEST CHANGES]
[1-2 sentences explaining the recommendation]
```

The Changes Overview comes first — orient the reader before auditing the details. List every new and modified file with its responsibility and its layer, the new behaviour it enables, and which spec rules it addresses.

Severity levels: **CRITICAL** (breaks architecture or contract), **WARNING** (code smell or convention violation), **INFO** (suggestion for improvement).

## Boundaries

- Do NOT modify any files — not even CLAUDE.md. This is a read-only review; propose CLAUDE.md changes in the report instead.
- Do NOT run tests or build the project. Only inspect the source code.
- Do NOT review files outside the scope of the current feature.
- Do NOT suggest refactoring beyond what the architecture rules require — this is a compliance review, not a rewrite.
- STOP after presenting the report. Wait for the user to decide what to do with the findings.