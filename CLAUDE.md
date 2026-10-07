# CLAUDE.md

## Project

SpringBoot microservice implementing a order management system with REST API, persistence, and validation.

## Build & Run

Uses a locally installed Maven (`mvn`, 3.9+ recommended); Java 21 required (see `pom.xml` `<java.version>`).

```bash
mvn spring-boot:run           # run the app
mvn verify                    # run ALL tests: unit (*Test) + acceptance (*IT)
mvn test                      # run unit tests (*Test) only
mvn -Dtest=ClassName test     # run a single unit test class
mvn -Dtest=ClassName#method test   # run a single unit test method
mvn -Dit.test=ClassNameIT verify   # run a single acceptance test class
mvn clean package             # build the jar
```

Acceptance tests (`*IT`) run via `maven-failsafe-plugin` during `verify`; surefire (`test`) skips them.

Stack: `spring-boot-starter-web`, `spring-boot-starter-data-jpa`, `spring-boot-starter-validation`, H2 (runtime scope, used by tests).
The MySQL driver is NOT yet declared in `pom.xml` — add `com.mysql:mysql-connector-j` (runtime) before running against MySQL.

## Database
Production persistence is MySQL. Hibernate is `ddl-auto=validate` and never generates schema. Connection is configured in `src/main/resources/application.properties` and `src/test/resources/application.properties`.

Tests run against H2 in MySQL compatibility mode (`MODE=MySQL`).

### Schema is explicit DDL, never Hibernate
`ddl-auto=validate` applies in tests too, and H2 starts empty — so Hibernate validation fails at
context startup unless the schema already exists. The schema is therefore owned by hand-written DDL:

- `src/test/resources/schema.sql` holds the test DDL, run at startup via `spring.sql.init.mode=always`.
  Spring Boot orders script init before the `EntityManagerFactory`, so the tables exist by the time
  Hibernate validates them.
- Production DDL is applied out of band (migration script or DBA), not by the application.
- `schema.sql` is not generated. When an entity gains or changes a column, update the DDL in the
  SAME commit — a mismatch surfaces as a context-startup failure in every `@SpringBootTest`, not as a
  single failing assertion.

### Enums in entities
Persist enums with `@Enumerated(EnumType.STRING)` (never ORDINAL) and a matching `VARCHAR` column in
`schema.sql`.

## Coding Conventions

### Money
BigDecimal for ALL monetary values. NEVER float, double, or int.
Always explicit RoundingMode.DOWN, scale 2.
BigDecimal.valueOf() or new BigDecimal("...") — NEVER new BigDecimal(double).

### Java 21
Records for value objects, sealed interfaces, pattern matching.
No Lombok — records replace it.

### REST & Spring
The project code will use Spring Boot 4.1.x, which is compatible with Java 21+.
Constructor injection only (no field @Autowired).
@Valid on request bodies. 201 create, 200 query, 400 validation, 404 not found.
Domain exceptions (exception/) for business rule violations. Map to HTTP in the controller layer only
(a @RestControllerAdvice in controller/).
Never swallow exceptions or leak infrastructure details.

### Error responses
Every error response body is `dto/ErrorResponse(String message)`, returned by the single
`@RestControllerAdvice` in `controller/ApiExceptionHandler` — one `@ExceptionHandler` per domain exception.
Domain exception messages read `"<Business reason>: <id>"`, e.g. `"Customer not found: 42"`.

## Testing
Test levels — pick the lowest one that can express the behaviour:

- Acceptance (`*IT`, `src/test/java/<base package>/acceptance/`) — `@SpringBootTest` + MockMvc, full
  stack against H2, no mocks. Seed and clean tables with `JdbcTemplate` (there is no customer/product API);
  NEVER through repositories or services.
- Service (`*Test`, same package) — plain JUnit 5 + Mockito, repositories mocked, no Spring context.
  Business rules are tested here.
- Controller (`*Test`, same package) — `@WebMvcTest` with the service mocked (`@MockitoBean`).
  HTTP mapping only: status codes, `@Valid`, `ApiExceptionHandler` error bodies.
- Repository (`*Test`, same package) — `@DataJpaTest`, only for custom queries.
- DTOs have no dedicated tests — they carry no logic; their Bean Validation annotations are
  covered by the controller tests.

Assertions: JUnit 5 only — `org.junit.jupiter.api.Assertions` (`assertEquals`, `assertThrows`, `assertAll`, ...).
NEVER AssertJ (`org.assertj.*`). MockMvc's own `andExpect(status()/jsonPath(...))` matchers are fine.
For money, `assertEquals(new BigDecimal("1.60"), actual)` — `BigDecimal.equals` checks scale, so this
also enforces scale 2.

## Architecture: classic layered (n-tier) architecture
This is a standard Spring Boot layered architecture. The layers are:

    - Controller (controller/) - @RestController annotated controller handle HTTP and input validation

    - Service (service/) - @Service annotated service handle business logic and orchestration

    - Repository (repository/) - @Repository annotated repository handle persistence and data access via Spring Data JPA
    
    - Model (model/) - JPA entities that map to database tables
    
    - DTO (dto/) - Data Transfer Objects for request and response payloads

    - Exception (exception/) - domain exceptions for business rule violations; thrown by services, mapped to HTTP by a @RestControllerAdvice in controller/

    - Config (config/) - Configuration classes for Spring Boot and application settings

Dependencies flow one way: controller → service → repository. Never the reverse.
Dto NEVER import org.springframework.* or jakarta.persistence.* packages.
Exceptions NEVER import org.springframework.* or carry HTTP status codes.
Controllers NEVER contain business logic.
Services NEVER contain persistence logic.
Repositories NEVER contain business logic.

## Development Process

Follow these steps for every feature. Do NOT skip steps.

Step 1: Discovery — Run `/sdd-discovery`.
Propose rules, surface questions with options, let the user decide.
Present the complete spec in chat. STOP. User reviews and approves.
Save to docs/spec/<feature>.md ONLY after approval.
Do NOT proceed if the spec has unresolved questions.
Re-read the saved spec before continuing.

Step 2: High-Level Design — Run `/sdd-hld`.
Context, component view, API, data model, key flows, error catalogue, design decisions,
rule traceability. Surface design choices as questions with options, let the user decide.
Save directly (no approval prompt) to docs/design/<feature>-hld.md and the OpenAPI contract
to docs/api/<feature>.yaml. STOP. User reviews the saved files; requested changes are applied to them.

Step 3: Low-Level Design — Run `/sdd-lld`.
Per package: class and method signatures, entity ↔ column mapping, DTO validation, exceptions,
exact DDL for schema.sql, test plan per rule/example, implementation order. No method bodies.
Save directly (no approval prompt) to docs/design/<feature>-lld.md. STOP. User reviews the
saved file; requested changes are applied to it.
No test or production code is written before the user has reviewed both designs.

Step 4: Acceptance Test — Run `/sdd-acceptance-test`.
Write test for the NEXT rule only.
@Nested = rule, test = example. @SpringBootTest + MockMvc.
Run the `spec-compliance` agent for the rule; fix the test until every example is covered.
Complete Step 5 until this rule is GREEN before writing the next.

Step 5: TDD (Inner Loop) — Run `/sdd-tdd`.
RED → GREEN → REFACTOR → OUTER CHECK → DESIGN CHECK → CHALLENGE.
Read the spec, HLD, LLD and OpenAPI contract first; STOP if any is missing.
For the red acceptance example, write ONE failing unit test (`*Test`, next to the
class under test). Minimum code to pass, following the LLD. Refactor.
Run ALL tests (`mvn verify`), then check whether the acceptance test is green.
Run the `design-compliance` agent; fix any DRIFT or propose an LLD change.
Propose an edge case; if the user approves it, it becomes the next RED (before the
remaining missing behaviour).
STOP after each cycle. Repeat cycles until every example of the rule is green.

Step 6: Review — Run `/sdd-review`.
Verify coverage, boundaries, no AI smells.
The review is read-only; it proposes CLAUDE.md updates if new conventions emerged — apply them after the user agrees.

### Workflow documentation
`README.md` (repo root) is the human-readable guide to this process. Whenever a change touches
`.claude/commands/sdd-*.md`, `.claude/agents/`, `.claude/settings.json` or the Development Process
above, update `README.md` in the SAME change: step descriptions, the overview table and
diagrams, the table of contents (with its explicit `<a id>` anchors and right-aligned
"Back to top" links), and the enforcement tables.