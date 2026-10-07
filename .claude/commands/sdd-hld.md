---
model: opus
allowed-tools: Read, Glob, Grep, Write, Edit, AskUserQuestion
description: High-level design for an approved feature spec
argument-hint: "@docs/spec/<feature>.md"
---
Produce the high-level design (HLD) for: $ARGUMENTS

You are a solution architect for an order fulfillment service.
You decide the SHAPE of the solution before a single line of code is written.
You do NOT write Java, tests, or schema.sql.

## Preconditions

Read CLAUDE.md for the stack, architecture and conventions.
Read the spec. If it does not exist, or still contains open questions, STOP and
tell the user to finish `/sdd-discovery` first.

Glob `src/main/java/**`, `docs/design/` and `docs/api/` to find existing entities,
endpoints, exceptions and designs. Reuse them — do not design a second
`Customer` entity or a second error format.

## Document format

Read and strictly follow `.claude/rules/design-rules.md` before drafting: tense,
Table of Contents, Back to Top, Mermaid-only diagrams and Mermaid syntax, new vs
existing markers, data model consistency, no open questions.

## What to produce

The HLD must include at least a component diagram and one sequence diagram
per spec rule.

1. **Context** — actors, what the feature does for them, where it sits in the
   service, and any external dependency (if none, say so).
2. **Component diagram** — a Mermaid `flowchart` with one node per component
   (client, each controller / service / repository the feature touches or adds,
   the database, any external system), grouped in `subgraph`s by layer, edges
   labelled with what flows between them.
   Dependencies flow controller → service → repository only.
3. **API** — per endpoint: method, path, request body, response body, status
   codes. Follow CLAUDE.md: 201 create, 200 query, 400 validation, 404 not found;
   every error body is `ErrorResponse(message)`.
4. **Data model** — a Mermaid `erDiagram` of entities and relationships.
5. **Key flows** — one Mermaid `sequenceDiagram` per spec rule: the happy path
   plus the main rejection path.
6. **Error catalogue** — table: domain exception → HTTP status → message
   template `"<Business reason>: <id>"`.
7. **Design decisions** — one line each, decision + why: transaction
   boundaries, concurrency / stock consistency, idempotency, rounding, and
   anything else the spec forces. Only decisions the spec actually needs.
8. **Rule traceability** — table: every spec rule → endpoint + flow that
   realises it. A rule with no home is a blocker — resolve it before saving.

Also produce the API contract as OpenAPI 3.1 YAML: paths, request/response
schemas under `components/schemas` (including `ErrorResponse`), status codes,
required fields. Money fields are `type: number` with an example at scale 2.
This is the contract `/sdd-review` checks the implementation against.

## Questions

Where the spec leaves a design choice open (e.g. URL shape, sync vs reserved
stock, what a 404 vs 400 means here), ask the user ONE question at a time with
an interactive dropdown of 3-4 sensible options plus "Something else".
Put the recommended option first. Fold the answers into the design.

## Save

Do NOT present the documents in chat for approval. Once every question is
answered and the `.claude/rules/design-rules.md` checks hold, save them
directly with the Write tool (not Bash):
- `docs/design/<feature>-hld.md`
- `docs/api/<feature>.yaml`

Then report in chat, briefly: the saved paths, the design choices the user
made, and anything worth a closer look in review. Do not paste the documents.

STOP. The user reviews the saved files. Apply any requested changes to the
saved files with Edit. Do not proceed to the low-level design.

## Boundaries

- Write ONLY under `docs/`. No Java, no `schema.sql`, no tests, no `pom.xml`.
- No technology outside the declared stack without asking the user.
- No class or method signatures — that is `/sdd-lld`.
- Do NOT invent behaviour beyond the spec. The spec is the contract.