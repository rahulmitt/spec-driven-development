#!/bin/bash
# Process and time-budget helpers for the documentation hook.
# Sourced by pre-commit-documentation.sh — not executed directly.

# Start the documentation time budget: DOC_TIME_BUDGET seconds from now.
start_time_budget() {
 DOC_DEADLINE=$(( $(date +%s) + DOC_TIME_BUDGET ))
}

# Return 0 while the time budget started by start_time_budget has not run out.
time_budget_left() {
 [ "$(date +%s)" -lt "$DOC_DEADLINE" ]
}

# Run <command...> but kill it after DOC_CALL_TIMEOUT seconds.
# Runs it without a limit when neither timeout (GNU) nor gtimeout (macOS coreutils) exists.
run_with_timeout() {
 if command -v timeout >/dev/null 2>&1; then
   timeout "$DOC_CALL_TIMEOUT" "$@"
 elif command -v gtimeout >/dev/null 2>&1; then
   gtimeout "$DOC_CALL_TIMEOUT" "$@"
 else
   "$@"
 fi
}

# Kill process <pid> and all its descendants (children first).
kill_process_tree() {
 local child
 for child in $(pgrep -P "$1" 2>/dev/null); do
   kill_process_tree "$child"
 done
 kill "$1" 2>/dev/null
}
