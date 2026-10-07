#!/usr/bin/env bats
# Tests for lib/doc_writer.sh: doc naming and generation for one target.

load helpers/common

setup() {
 load_libs
 install_claude_stub
 DOC_DIR="$BATS_TEST_TMPDIR/docs"
 mkdir -p "$DOC_DIR"
 COMMIT_MSG="Add order status"
 DOC_TIME_BUDGET=60
 start_time_budget
}

@test "slugify_title makes a kebab-case filename stem" {
 run slugify_title "OAuth Token Refresh"
 [ "$output" = "oauth-token-refresh" ]

 run slugify_title "C++ & Java  Interop"
 [ "$output" = "c-java-interop" ]
}

@test "resolve_doc_file uses the file named after the title when it exists" {
 touch "$DOC_DIR/order-status.md"
 run resolve_doc_file "$DOC_DIR" "Order Status" "orders" "diff"
 [ "$output" = "$DOC_DIR/order-status.md" ]
 [ ! -f "$STUB_LOG" ]   # no similarity call needed
}

@test "resolve_doc_file uses an existing doc Claude matches" {
 touch "$DOC_DIR/order-lifecycle.md"
 STUB_MATCH="order-lifecycle.md" run resolve_doc_file "$DOC_DIR" "Order Status" "orders" "diff"
 [ "${lines[-1]}" = "$DOC_DIR/order-lifecycle.md" ]
}

@test "resolve_doc_file creates a new file when Claude answers NEW" {
 touch "$DOC_DIR/payments.md"
 run resolve_doc_file "$DOC_DIR" "Order Status" "orders" "diff"
 [ "$output" = "$DOC_DIR/order-status.md" ]
}

@test "document_target writes one doc per title and lists it" {
 STUB_TITLES=$'Order Status\nPayment Retry' document_target "$DOC_DIR" "orders" "diff" "$BATS_TEST_TMPDIR/written"
 [ "$(head -1 "$DOC_DIR/order-status.md")" = "# Order Status" ]
 [ "$(head -1 "$DOC_DIR/payment-retry.md")" = "# Payment Retry" ]
 [ "$(wc -l < "$BATS_TEST_TMPDIR/written")" -eq 2 ]
}

@test "document_target does not write a malformed doc" {
 printf '#!/bin/bash\ncat > /dev/null\necho "Order Status"\n' > "$STUB_BIN/claude"
 run document_target "$DOC_DIR" "orders" "diff" "$BATS_TEST_TMPDIR/written"
 [[ "$output" == *"empty or malformed, not written"* ]]
 [ ! -f "$DOC_DIR/order-status.md" ]
}

@test "document_target skips everything once the time budget is spent" {
 DOC_DEADLINE=0
 run document_target "$DOC_DIR" "orders" "diff" "$BATS_TEST_TMPDIR/written"
 [[ "$output" == *"time budget exhausted"* ]]
 [ ! -f "$STUB_LOG" ]
}
