---
paths:
  - "src/test/java/**"
---

You are editing test code.

Tests are executable specifications.
@DisplayName on every class and method.
Use @Nested for grouping related tests.
Use @ParameterizedTest to model data-driven tests

# Assertions
JUnit 5 assertions only: org.junit.jupiter.api.Assertions (assertEquals,
assertThrows, assertAll, ...). NEVER import org.assertj.*.
MockMvc matchers (status(), jsonPath(...).value(...)) are fine in web tests.
Money: assertEquals(new BigDecimal("1.60"), actual) — equals also checks scale 2.

# Naming conventions (Maven best practice)
Acceptance tests → *IT (run by maven-failsafe-plugin via mvn verify).
All other tests → *Test (unit tests, run by surefire via mvn test).
Acceptance = @SpringBootTest + MockMvc, wiring controller → service → repository.
Acceptance tests live in src/test/java/<base package>/acceptance/.
Unit tests live in the same package as the code they test.

# Schema
Tests run against H2 in MySQL mode with ddl-auto=validate, so the schema must
already exist. src/test/resources/schema.sql owns the test DDL. If an entity
changed, update schema.sql in the same change — a mismatch fails context
startup in EVERY @SpringBootTest, not just one assertion.

NEVER recalculate expected values.
NEVER modify a test to make it pass.
