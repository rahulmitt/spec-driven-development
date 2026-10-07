---
paths:
  - "docs/design/**"
---

You are writing a design document (HLD or LLD).

These rules apply to the saved document.

# 1. Tense
Every document MUST be written in the present simple tense
(e.g. "The service locks the ordered products", "The controller returns 201").
This applies to prose, bullets, table cells and diagram notes.
State hard constraints with RFC 2119 keywords (MUST / MUST NOT / SHOULD / MAY),
e.g. "Stock MUST NOT go negative".
Code identifiers, message templates and quoted spec text stay verbatim.

# 2. Table of Contents
Every design document MUST have a Table of Contents at the top: the title, then a
`## Table of Contents` section preceded by the explicit anchor `<a id="table-of-contents"></a>`.
It lists every `##` section and every `###` sub-section as a link, with sub-sections indented
under their section.
Every linked heading gets its own explicit `<a id="..."></a>` anchor (kebab-case) on the line
directly above it, and the ToC links to those anchors.

# 3. Back to Top
Every `##` section and every `###` sub-section (except the Table of Contents itself) MUST end
with a `[Back to Top]` link, followed by a blank line. Clicking it MUST land on the Table of
Contents. Use this exact line:

```html
<p align="right"><a href="#table-of-contents">[Back to Top]</a></p>
```

# 4. Alignment
The `[Back to Top]` link MUST be right-aligned (`<p align="right">`), never inline or left-aligned.

# 5. Diagrams are Mermaid
Every diagram MUST be a fenced ```mermaid block — never ASCII art, PlantUML or images.

# 6. Mermaid syntax
A diagram that doesn't parse is a defect:
- No `;` inside any label or message (entity codes like `#lt;` excepted). In a
  `sequenceDiagram` it ends the statement.
  Use `,` or `→` instead (e.g. `BEGIN, SELECT … FOR UPDATE`).
- No raw `<…>` placeholders in labels. Mermaid reads them as HTML tags and drops the text.
  Write `#lt;id#gt;` in sequence diagrams and `&lt;id&gt;` in flowchart labels.
  `<br/>` is the only tag allowed.
- Flowchart labels with `( ) [ ] { } | : "` go inside double quotes: `A["OrderService (new)"]`.
- `erDiagram` attribute types are single tokens: `DECIMAL_19_2`, not `DECIMAL(19,2)`.
- Never use the bare word `end` as a flowchart node id or label (it closes a `subgraph`).

# 7. New vs existing
Every diagram MUST mark what the feature adds or changes: components and tables as new vs
existing, classes as `<<new>>` / `<<modified>>`. Every class in a package listing is marked NEW
or MODIFIED.

# 8. Data model consistency
- Enums persist as STRING (`VARCHAR`); money columns are `DECIMAL(19,2)` (written
  `DECIMAL_19_2` in an `erDiagram`).
- The `erDiagram` MUST match the data definition it illustrates — the HLD data model, or the
  LLD DDL — with the same tables, columns, types, keys and relationships.

# 9. No open questions
The final document MUST contain no unresolved questions. Open choices are asked and folded in
before saving.

# Check before saving
- Present simple throughout; constraints use RFC 2119 keywords.
- Every heading is in the ToC.
- Every ToC link resolves to an anchor.
- One right-aligned `[Back to Top]` at the end of every section and sub-section.
- Every diagram is a ```mermaid block, re-read against the syntax rules in section 6.
- New vs existing is marked in every diagram and package listing.
- The `erDiagram` matches the data model / DDL exactly.
- No unresolved questions remain.
