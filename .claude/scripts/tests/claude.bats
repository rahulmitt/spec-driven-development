#!/usr/bin/env bats
# Tests for lib/claude.sh: claude CLI calls and parsing of their raw output.

load helpers/common

setup() {
 load_libs
}

# ── parse_titles ─────────────────────────────────────────────────────────────

@test "parse_titles keeps a plain Title Case title" {
 run parse_titles <<< "Order Status Transition"
 [ "$output" = "Order Status Transition" ]
}

@test "parse_titles strips list markers, markdown, quotes and a Title: prefix" {
 run parse_titles <<< $'Here are the titles:\n1. **Order Validation**\n- "Payment Retry Logic".\nTitle: Stock Reservation'
 [ "$output" = $'Order Validation\nPayment Retry Logic\nStock Reservation' ]
}

@test "parse_titles drops sentences and keeps at most three titles" {
 run parse_titles <<< $'this is not a title\nOne\nTwo\nThree\nFour'
 [ "$output" = $'One\nTwo\nThree' ]
}

# ── parse_doc_filename ───────────────────────────────────────────────────────

@test "parse_doc_filename returns a bare .md filename" {
 run parse_doc_filename <<< '"order-status.md"'
 [ "$output" = "order-status.md" ]
}

@test "parse_doc_filename returns nothing for NEW or a path" {
 run parse_doc_filename <<< "NEW"
 [ -z "$output" ]

 run parse_doc_filename <<< "../secrets.md/x"
 [ -z "$output" ]
}

# ── parse_markdown_doc ───────────────────────────────────────────────────────

@test "parse_markdown_doc drops preamble before the first heading" {
 run parse_markdown_doc <<< $'Sure, here is the doc:\n\n# Title\n\nBody\n\n'
 [ "$output" = $'# Title\n\nBody' ]
}

@test "parse_markdown_doc unwraps a code fence around the whole document" {
 run parse_markdown_doc <<< $'```markdown\n# Title\n\nBody\n```\nHope this helps!'
 [ "$output" = $'# Title\n\nBody' ]
}

@test "parse_markdown_doc keeps inner code fences" {
 run parse_markdown_doc <<< $'# Title\n\n```mermaid\nsequenceDiagram\n```'
 [ "$output" = $'# Title\n\n```mermaid\nsequenceDiagram\n```' ]
}

# ── ask_claude ───────────────────────────────────────────────────────────────

@test "ask_claude runs claude isolated, with the given model" {
 install_claude_stub
 echo "Derive a concise title" | ask_claude haiku > /dev/null
 run cat "$STUB_LOG"
 [ "$output" = "-p --output-format text --tools  --strict-mcp-config --setting-sources user --model haiku" ]
}

@test "ask_claude without a model uses the CLI default" {
 install_claude_stub
 echo "Derive a concise title" | ask_claude "" > /dev/null
 run cat "$STUB_LOG"
 [[ "$output" != *"--model"* ]]
}

@test "ask_claude gives up after DOC_CALL_TIMEOUT seconds" {
 command -v timeout >/dev/null || skip "timeout not installed"
 STUB_BIN="$BATS_TEST_TMPDIR/bin"
 mkdir -p "$STUB_BIN"
 printf '#!/bin/bash\nsleep 30\n' > "$STUB_BIN/claude"
 chmod +x "$STUB_BIN/claude"
 PATH="$STUB_BIN:$PATH"
 DOC_CALL_TIMEOUT=1

 SECONDS=0
 run ask_claude "" <<< "prompt"
 [ "$status" -eq 124 ]
 [ "$SECONDS" -lt 10 ]
}
