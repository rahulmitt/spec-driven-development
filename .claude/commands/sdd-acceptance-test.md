---
model: sonnet
description: Write a failing acceptance test for the next spec rule
argument-hint: "<next rule per the LLD Implementation order> @docs/spec/<feature>.md @docs/design/<feature>-lld.md"
---
Write a failing acceptance test for: $ARGUMENTS

Read CLAUDE.md for project conventions before writing anything.

## Preconditions

Read all four artifacts before writing anything. If any is missing, STOP and
tell the user which step to run first.

- `docs/spec/<feature>.md` (`/sdd-discovery`) — the full rule, its examples
  and counter-examples.
- `docs/design/<feature>-hld.md` (`/sdd-hld`) — the error catalogue: exact
  message templates for error responses.
- `docs/api/<feature>.yaml` (`/sdd-hld`) — paths, field names, status codes.
- `docs/design/<feature>-lld.md` (`/sdd-lld`) — the test plan (use its
  @Nested / @Test names) and the DDL (use it when touching schema.sql).

If these disagree (e.g. the LLD test plan lists an example the spec does not,
or the OpenAPI status code differs from the HLD), STOP and raise the conflict.
Never resolve it silently.

## Structure

One outer class per feature, named <Feature>IT, in
src/test/java/<base package>/acceptance/<Feature>IT.java.
One @Nested inner class per rule — name it after the rule.
One @Test per example from the spec.

Use @DisplayName with the spec's exact business language:
- Class: the rule name
- Method: "The one where..." text from the spec

## How to test

Test through the REST API using @SpringBootTest + MockMvc.
Send real HTTP requests. Assert real HTTP responses.
NEVER call services or repositories directly —
this is an acceptance test, not a unit test.

Tests run against H2 in MySQL mode with ddl-auto=validate. If the rule needs a
new table or column, copy the LLD's DDL for this rule (and only this rule) into
src/test/resources/schema.sql — otherwise the Spring context fails to start.
Never invent DDL here — if the LLD's DDL is missing or wrong, STOP and raise it.

Assert exact values from the spec examples.
For money: .andExpect(jsonPath("$.amount").value("1.60")).
Take request paths, JSON field names and status codes from the OpenAPI
contract. For error responses, assert `$.message` with the exact template
from the HLD error catalogue, e.g. `"Customer not found: 42"`.
Use JUnit 5 assertions (org.junit.jupiter.api.Assertions) for anything
MockMvc matchers don't cover — NEVER AssertJ.

## What NOT to do

Do NOT write production code. The test MUST FAIL.
A passing test means you tested nothing.
Do NOT write tests for all rules at once.
One rule only — the one specified in the arguments.
Do NOT invent examples beyond what the spec provides.
The spec is the contract.
Do NOT use mocks in acceptance tests.
Wire the full stack: controller → service → repository → database.

## When you're done

Run the test with `mvn -Dit.test=<Feature>IT verify`
(failsafe runs *IT; `-Dtest` / `mvn test` will NOT pick it up).
Confirm it fails for the RIGHT reason:
- Missing endpoint or behaviour → 404, wrong status, or compilation error (good)
- Fails for another reason (context startup failure, bad seed data, wrong
  URL or JSON path in the test) → wrong reason: investigate and fix the TEST,
  then re-run
- Test passes → something is wrong: investigate and fix the TEST, then re-run

Never write production code to change how the test fails.

## Coverage check — does the test mirror the spec?
Use the Agent tool with `subagent_type: "spec-compliance"`. The agent does
not see this conversation, so its prompt must name the spec file, the rule
just tested, and the `<Feature>IT` file. Do not skip this step.
Act on the `Result:` line it returns:
- COVERED → done.
- GAPS (any PARTIAL / MISSING / UNSPECIFIED for this rule) → fix the TEST
  (add the missing example, remove the invented one), re-run it to confirm
  it still fails for the right reason, then re-run the check.

Report: which rule you tested, how many examples, the failure reason, and
the coverage check result.

STOP. Do not proceed to implementation.