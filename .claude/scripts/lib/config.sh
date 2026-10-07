#!/bin/bash
# Settings and dependency checks for the documentation hook.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
# Every setting can be overridden from the environment (defaults shown):
#   DOC_MAX_DIFF_BYTES=60000  diff sent per prompt; larger diffs become --stat + truncated diff
#   DOC_TIME_BUDGET=150       seconds; no new claude call starts after this
#   DOC_CALL_TIMEOUT=120      seconds; a single claude call is killed after this
#   DOC_PARALLEL=4            documentation targets (modules) processed concurrently
#   DOC_FAST_MODEL=haiku      model for the title + similarity calls (empty → CLI default)
# Keep the hook "timeout" in .claude/settings.json above DOC_TIME_BUDGET + DOC_CALL_TIMEOUT.

DOC_MAX_DIFF_BYTES=${DOC_MAX_DIFF_BYTES:-60000}
DOC_TIME_BUDGET=${DOC_TIME_BUDGET:-150}
DOC_CALL_TIMEOUT=${DOC_CALL_TIMEOUT:-120}
DOC_PARALLEL=${DOC_PARALLEL:-4}
DOC_FAST_MODEL=${DOC_FAST_MODEL-haiku}

# Docs folder, relative to the repo root or to a Maven module.
DOCS_SUBDIR="docs/technical"

# Commands the documentation pipeline needs once it has decided to run.
# jq is checked separately: it is needed earlier, to recognise a Claude Code commit.
PIPELINE_DEPENDENCIES="claude perl pgrep"

# Print the commands from <command...> that are not on PATH, space-separated.
# Output is empty when all are available.
missing_commands() {
 local cmd missing=""
 for cmd in "$@"; do
   command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
 done
 echo "${missing# }"
}
