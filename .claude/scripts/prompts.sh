#!/bin/bash
# Claude prompt templates for the pre-commit documentation pipeline.
# Each function prints the full prompt to stdout so callers can pipe it to `claude -p`.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
# To tune a prompt, edit only this file. The orchestration logic in
# pre-commit-documentation.sh does not need to change.

# Prompt: derive a concise title (or multiple titles for split topics) from a staged diff.
#
# Args:
#   $1  project name
#   $2  commit message
#   $3  full staged diff for the project
prompt_derive_title() {
 local project="$1"
 local commit_msg="$2"
 local diff="$3"

 cat <<PROMPT
Analyze this staged git diff for the '${project}' project and the commit message below.
Derive a concise, descriptive title that captures the primary technical concern of the change.
If the diff clearly contains two or more completely unrelated concerns, return one title per concern.

Commit message: ${commit_msg}

Diff:
\`\`\`diff
${diff}
\`\`\`

Rules:
- Return ONLY the title(s), one per line, no explanation, no punctuation at the end
- Each title should be 3-6 words, title case (e.g. "OAuth Token Refresh", "Workflow Pause Step")
- Do not include the project name in the title
- If there is only one concern (the common case), return exactly one line
PROMPT
}

# Prompt: decide whether a new title matches an existing doc file closely enough to update it.
#
# Args:
#   $1  title of the new/updated document
#   $2  project name
#   $3  first ~80 lines of the staged diff (for context)
#   $4  space-separated list of existing .md filenames in the docs folder
prompt_similarity_check() {
 local title="$1"
 local project="$2"
 local diff_excerpt="$3"
 local existing_names="$4"

 cat <<PROMPT
You are deciding whether a new technical document should be created or an existing one updated.

New document title: "${title}"
Staged diff summary (project: ${project}):
\`\`\`diff
${diff_excerpt}
\`\`\`

Existing documents in the project's technical docs folder:
${existing_names}

If one of the existing documents clearly covers the same topic as "${title}", return ONLY that filename (e.g. "oauth-token-refresh.md").
If none are a close match, return ONLY the word: NEW
PROMPT
}

# Prompt: generate or update a technical Markdown document.
#
# Args:
#   $1  title of the document
#   $2  project name
#   $3  commit message
#   $4  full staged diff for the project
#   $5  existing document content (empty string → create new)
prompt_generate_doc() {
 local title="$1"
 local project="$2"
 local commit_msg="$3"
 local diff="$4"
 local existing_content="$5"

 local update_instruction
 if [ -n "$existing_content" ]; then
   update_instruction="The existing documentation is:
\`\`\`markdown
${existing_content}
\`\`\`
Update it to reflect the new changes. Follow these rules strictly:
- Keep ALL existing accurate content; do not remove or summarise away information that is still correct.
- Diagrams must be EXTENDED or MERGED, never replaced:
 - If a Mermaid sequence diagram already exists, add the new flow as additional participants/messages inside the same diagram block. Do not start a new diagram for the same section.
 - If an ASCII component tree already exists, add new components to it rather than replacing it.
 - Only replace a diagram if the existing one is factually wrong after this change (e.g. a renamed class).
- Add or revise only the sections and lines that are directly affected by the new staged change.
- If the change adds a new endpoint, add its row to any existing endpoint table and extend the sequence diagram to include its flow."
 else
   update_instruction="Write a new technical document titled \"${title}\"."
 fi

 cat <<PROMPT
You are a technical documentation writer for the Java/Spring Boot project '${project}'.

A git commit is about to be made with this message:
${commit_msg}

The staged diff for '${project}' is:
\`\`\`diff
${diff}
\`\`\`

${update_instruction}

Requirements:
- Start with a # heading using the title: ${title}
- Format: Markdown
- Sections to cover (as applicable): Overview, Key Components, API / Endpoints Changed, Persistence, Configuration, Notable Design Decisions
 - Key Components: Spring beans by layer (@RestController, @Service, @Repository, @Configuration), entities, DTOs, exceptions
 - API / Endpoints Changed: HTTP method, path, request/response bodies, status codes, validation and error responses
 - Persistence: JPA entities, repository queries, schema/DDL or migration changes
 - Configuration: application properties/YAML, profiles, Maven/Gradle dependency changes
- Be concise. Only document what is non-obvious from reading the code.
- Do NOT include a timestamp or commit SHA in the output.
- Output ONLY the raw markdown content, no explanation, no code fences wrapping the entire output.

Diagram rules — apply the FIRST matching rule; only skip if the change is a single-line tweak or rename with nothing structural:
- REQUIRED ASCII diagram when the diff introduces or restructures classes, layers, or components
 (e.g. new controller/service/entity, refactored package structure, new config hierarchy).
 Show ownership and relationships using an indented tree. Place it in the Key Components section.
- REQUIRED Mermaid sequence diagram (in a \`\`\`mermaid block with sequenceDiagram) when the diff adds or changes
 a multi-step flow involving API calls, service interactions, token lifecycles, or request/response chains.
 Place it in the API / Endpoints Changed section.
- REQUIRED Mermaid flowchart (in a \`\`\`mermaid block with flowchart TD) when the diff adds decision logic,
 retry/recovery branching, or conditional execution paths. Place it in the Notable Design Decisions section.
- Never include both a Mermaid and an ASCII diagram for the same concept — pick the more appropriate one.
- A change may warrant BOTH an ASCII diagram (structure) AND a sequence diagram (runtime flow) in
 different sections — that is allowed and encouraged for new CRUD endpoints.
- Only omit all diagrams for trivial changes: single-line config tweaks, renames, or comment edits.
PROMPT
}