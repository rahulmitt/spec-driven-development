#!/bin/bash
# Git helpers for the documentation hook: staged diffs and the "already documented" marker.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
# All commands honour GIT_INDEX_FILE, which git sets for its hooks (for `git commit -a`
# it points at a temporary index), so they always see what is about to be committed.

# Return 0 if anything is staged.
has_staged_changes() {
 ! git diff --cached --quiet 2>/dev/null
}

# Print the hash of the staged tree; empty on failure (e.g. unmerged entries).
staged_tree_hash() {
 git write-tree 2>/dev/null
}

# Print the staged diff for <pathspec...>, capped at DOC_MAX_DIFF_BYTES.
# Over the cap: a --stat summary (so every changed file is still visible) followed by the
# diff cut at the last complete line that fits, and a "[diff truncated ...]" marker.
staged_diff_capped() {
 local LC_ALL=C   # measure and cut in bytes, not characters
 local diff stat room truncated total shown
 diff=$(git diff --cached -- "$@" 2>/dev/null)
 [ -n "$diff" ] || return 0

 if [ "${#diff}" -le "$DOC_MAX_DIFF_BYTES" ]; then
   echo "$diff"
   return 0
 fi

 stat=$(git diff --cached --stat -- "$@" 2>/dev/null | head -c $((DOC_MAX_DIFF_BYTES / 4)))
 room=$((DOC_MAX_DIFF_BYTES - ${#stat} - 100))
 truncated=$(printf '%s' "$diff" | head -c "$room" | sed '$d')
 total=$(printf '%s\n' "$diff" | wc -l | tr -d ' ')
 shown=$(printf '%s\n' "$truncated" | wc -l | tr -d ' ')

 echo "$stat"
 echo
 echo "$truncated"
 echo "[diff truncated: showing $shown of $total lines]"
}

# ── Documented-tree marker ────────────────────────────────────────────────────
# When both hooks are installed, the Claude Code hook records the staged tree it documented;
# the native pre-commit hook then skips a commit with exactly that tree.

# Print the path of the marker file (inside .git).
documented_tree_marker_path() {
 git rev-parse --git-path docs-hook-done 2>/dev/null
}

# Record the current staged tree as documented.
record_documented_tree() {
 local tree marker
 tree=$(staged_tree_hash)
 marker=$(documented_tree_marker_path)
 [ -n "$tree" ] && [ -n "$marker" ] && echo "$tree" > "$marker"
}

# Return 0 if the current staged tree was already documented. The marker is single-use:
# it is removed whether or not it matches.
consume_documented_tree_marker() {
 local marker marked_tree current_tree
 marker=$(documented_tree_marker_path)
 [ -n "$marker" ] && [ -f "$marker" ] || return 1

 marked_tree=$(cat "$marker")
 rm -f "$marker"
 current_tree=$(staged_tree_hash)
 [ -n "$current_tree" ] && [ "$marked_tree" = "$current_tree" ]
}
