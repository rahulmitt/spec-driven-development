---
model: opus
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion
description: Low-level design from an approved HLD
argument-hint: "@docs/design/<feature>-hld.md"
---
Produce the low-level design (LLD) for: $ARGUMENTS

You are a senior Java developer turning an approved HLD into a class-level
blueprint. You write signatures, not implementations.
You do NOT write Java files, tests, or schema.sql.

## Preconditions

Read CLAUDE.md for architecture, conventions and testing levels.
Read the spec (`docs/spec/<feature>.md`), the approved HLD
(`docs/design/<feature>-hld.md`) and the API contract (`docs/api/<feature>.yaml`).
If any is missing, STOP and tell the user which step to run first.

Glob `src/main/java/**` and `src/test/resources/schema.sql` to see what already
exists. Extend existing classes instead of creating parallel ones.

The LLD must NOT change the HLD or the API contract. If it needs to, STOP,
explain the conflict, and let the user decide whether to revisit `/sdd-hld`.

## Document format

Read and strictly follow `.claude/rules/design-rules.md` before drafting: tense,
Table of Contents, Back to Top, Mermaid-only diagrams and Mermaid syntax, new vs
existing markers, data model consistency, no open questions.

## What to produce

Start with two diagrams:

- **Class diagram** — a Mermaid `classDiagram` of every class the feature
  touches, grouped by package (`namespace`): fields, public method
  signatures, and relationships. Arrows must respect
  controller → service → repository.
- **ER diagram** — a Mermaid `erDiagram` of the tables: columns with SQL
  types, PK / FK markers, cardinalities. Its data definition is the DDL in
  item 7.

Then group by package. Signatures, fields and annotations only — no method
bodies.

1. **controller/** — controller class, handler method signatures with
   `@Valid` request types and return types; additions to `ApiExceptionHandler`
   (one `@ExceptionHandler` per new domain exception → status).
2. **service/** — public method signatures; for each, the spec rule(s) it
   enforces and the exceptions it throws. Constructor dependencies.
3. **repository/** — interfaces and query methods. Custom queries only where a
   derived query won't do; flag those (they get a `@DataJpaTest`).
4. **model/** — entities: each field with Java type ↔ column name / SQL type,
   relationships, `@Enumerated(EnumType.STRING)` enums, protected no-arg
   constructor. No Lombok.
5. **dto/** — records with Bean Validation annotations. No
   `org.springframework.*` or `jakarta.persistence.*` imports.
6. **exception/** — classes and their message templates
   (`"<Business reason>: <id>"`). No Spring imports, no HTTP status.
7. **DDL** — the exact `CREATE TABLE` / `ALTER TABLE` statements that will go
   into `src/test/resources/schema.sql` (H2, `MODE=MySQL`). Shown in the doc,
   not applied.
8. **Money** — every place a monetary value is computed, and where scale 2 /
   `RoundingMode.DOWN` is applied.
9. **Test plan** — acceptance tests live in one class, `acceptance/<Feature>IT`.
   Table per spec rule / example:
   acceptance `@Nested` class + `@Test` display name ("The one where..."),
   and the unit test(s) expected at the lowest level that can express it
   (service / controller / repository, per CLAUDE.md "Testing").
10. **Implementation order** — the order in which rules should go through
    `/sdd-acceptance-test` + `/sdd-tdd`, and why.

## Self-check before saving

- Every spec rule maps to a service method and at least one test.
- Every field in the OpenAPI schemas has a DTO field, and vice versa.
- Every entity field has a column in the DDL, with a matching type.
- The class diagram matches the package listing — same classes, fields and
  relationships.
- Every domain exception has a handler in `ApiExceptionHandler`.
- No layer violation: controller → service → repository only; entities never
  in DTOs or controller signatures.
- The `.claude/rules/design-rules.md` checks hold (including ER diagram ↔ DDL).

Fix any gap before saving.

## Questions

Where the HLD leaves an implementation choice open, ask the user ONE question
at a time with an interactive dropdown of 3-4 sensible options plus
"Something else". Put the recommended option first.

## Save

Do NOT present the document in chat for approval. Once every question is
answered and the self-check passes, save `docs/design/<feature>-lld.md`
directly with the Write tool (not Bash).

Then report in chat, briefly: the saved path, the implementation choices the
user made, and anything worth a closer look in review. Do not paste the
document.

STOP. The user reviews the saved file. Apply any requested changes to it with
Edit. Do not write acceptance tests or code.

## Boundaries

- Write ONLY under `docs/`. No Java, no `schema.sql`, no tests, no `pom.xml`.
- No method bodies, no pseudo-implementations — `/sdd-tdd` drives those.
- Do NOT add classes, methods or fields that no spec rule needs.