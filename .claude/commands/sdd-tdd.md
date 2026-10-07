---
model: sonnet
description: Run one TDD cycle (RED → GREEN → REFACTOR → OUTER CHECK → DESIGN CHECK → CHALLENGE → STOP)
argument-hint: "<acceptance example, e.g. PlaceOrderIT Rule 1 example 2> @docs/design/<feature>-lld.md"
---

Run ONE TDD cycle for: $ARGUMENTS

Read CLAUDE.md for architecture and testing conventions before writing any code.

## Preconditions

Read the design before writing any code. If any artifact is missing, STOP and
tell the user which step to run first.

- `docs/spec/<feature>.md` (`/sdd-discovery`) — the rule and example being driven.
- `docs/design/<feature>-hld.md` (`/sdd-hld`) — design decisions (transaction
  boundaries, rounding, concurrency) and the error catalogue.
- `docs/api/<feature>.yaml` (`/sdd-hld`) — paths, fields, status codes.
- `docs/design/<feature>-lld.md` (`/sdd-lld`) — classes, packages, method
  signatures, column mapping, DDL, test plan.

The design is the blueprint for this cycle. Code that does not match it is a
defect, even when every test passes.

## RED — write ONE failing unit test

Run the red acceptance test (`mvn -Dit.test=<Feature>IT verify`) and read
the failure. Pick the next SMALLEST behaviour it needs that doesn't exist yet.

Write ONE unit test (`*Test`) for that behaviour, in the same package as the class
under test (under `src/test/java`). Take the level and the class under test
from the LLD test plan row for this example. The levels are:
- Service — plain JUnit 5 + Mockito, repositories mocked, no Spring context.
  Assert with JUnit 5 `Assertions` (`assertEquals`, `assertThrows`) — never AssertJ.
  Business rules belong here (e.g. customer not found, customer not active).
- Controller — `@WebMvcTest` with the service mocked. HTTP mapping only:
  status codes, `@Valid`, `@RestControllerAdvice` error bodies.
- Repository — `@DataJpaTest`, only when there is a custom query.

Run it with `mvn -Dtest=<Class>#<method> test`. Read the failure message.
Understand WHY it fails before writing any production code.
If the test already passes, STOP — something is wrong.

## GREEN — minimum code to pass
Write the MINIMUM production code to make this one unit test pass.
Minimum means minimum:
- No extra methods "while we're here"
- No anticipating the next test
- No abstractions until refactoring demands them
- Hard-code if that's all this test requires

Follow the class names, packages and method signatures in
`docs/design/<feature>-lld.md`. Honour the HLD design decisions (transaction
boundaries, rounding, concurrency) and use the exact exception messages from
the HLD error catalogue. If the design turns out to be wrong, STOP and
propose a design change to the user — never diverge from it silently.

Respect architecture boundaries:
- Dto NEVER import org.springframework.* or jakarta.persistence.* packages.
- Controllers NEVER contain business logic.
- Services NEVER contain persistence logic.
- Repositories NEVER contain business logic.
- JPA entities live in model/ and are never exposed over HTTP.
- Domain exceptions live in exception/; map them to HTTP only in
  controller/ (@RestControllerAdvice).

Respect project conventions:
- BigDecimal for ALL money, scale 2, explicit RoundingMode.DOWN.
  Never new BigDecimal(double).
- Records for value objects. No Lombok. Constructor injection only.
- If an entity gains or changes a column, update
  src/test/resources/schema.sql in the SAME cycle — ddl-auto=validate
  means a mismatch fails context startup in every @SpringBootTest.

## REFACTOR — clean up with confidence
All tests are green. Now improve the code:
- Remove duplication
- Extract clear names
- Simplify conditionals
- Check that the code reads like the spec

Run ALL tests after refactoring with `mvn verify` — not just the current one.
(`mvn test` skips the *IT acceptance tests.)
If anything breaks, fix it before moving on.

## OUTER CHECK — is the acceptance example green?
Re-run the acceptance test: `mvn -Dit.test=<Feature>IT verify`.
- Green → the targeted example is done.
- Still red → name the behaviour that is still missing. It becomes the
  next cycle's RED (a new unit test) — unless the user approves a CHALLENGE
  edge case, which goes first. Do NOT start it now.

## DESIGN CHECK — does the code still match the design?
Use the Agent tool with `subagent_type: "design-compliance"`. The agent does
not see this conversation, so its prompt must name the feature (e.g.
`place-order`) and list every production file created or modified in this
cycle. Do not skip this step, even when the change looks trivial.
Act on the `Result:` line it returns:
- CONFORMS / NOT YET BUILT → nothing to do.
- DRIFT → if the code is wrong, fix it now (no new tests needed: this is a
  REFACTOR), then re-run `mvn verify` and the check. If the design is wrong,
  STOP and propose an LLD change to the user. Never leave DRIFT unreported.

## CHALLENGE — drive out edge cases
Before stopping, ask yourself:
"What else should this do?"
"What input could break this?"

Consider: zero/empty input, not-found, boundary values, rounding, invalid state, null, negative amounts,
duplicate requests.

Propose at least one edge case to the user.
If approved, that edge case becomes the next RED — as a unit test — even when
the acceptance test is still red. The missing behaviour named in OUTER CHECK
is picked up by the OUTER CHECK after that cycle.

## STOP
Report what you changed:
- Which unit test you added, and that it is now passing
- Acceptance test state: which examples are green / still red
- What production code you wrote or modified
- What you refactored
- Design conformance: CONFORMS, or the DRIFT found and how it was resolved
- What edge case you propose next

Do NOT write more than ONE new unit test per cycle.
Do NOT modify the acceptance test.
Do NOT add unrequested features or "improvements".
Do NOT modify any existing test to make it pass — fix the production code instead.

Wait for the user before starting the next cycle.