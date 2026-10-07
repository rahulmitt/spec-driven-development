# Shared helpers for the documentation hook tests.

SCRIPTS_SRC="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Source every lib module and the prompts into the test shell.
load_libs() {
 local module
 for module in config process hook_context git maven claude doc_writer targets; do
   # shellcheck source=/dev/null
   source "$SCRIPTS_SRC/lib/$module.sh"
 done
 # shellcheck source=/dev/null
 source "$SCRIPTS_SRC/prompts.sh"
}

# Create an empty git repo with one commit in $REPO, containing a copy of the scripts,
# and cd into it.
make_repo() {
 REPO="$BATS_TEST_TMPDIR/repo"
 git init -q "$REPO"
 cd "$REPO" || return 1
 git config user.name "Test"
 git config user.email "test@example.com"
 mkdir -p .claude
 cp -R "$SCRIPTS_SRC" .claude/scripts
 echo "initial" > README.md
 git add README.md .claude
 git commit -qm "initial"
}

# Put a fake `claude` on PATH that answers each prompt type with canned text:
#   title prompt      → $STUB_TITLES (default "Order Status Transition")
#   similarity prompt → $STUB_MATCH  (default NEW)
#   document prompt   → "# <title>" + a body line
# Every call's arguments are appended to $STUB_LOG.
install_claude_stub() {
 STUB_BIN="$BATS_TEST_TMPDIR/bin"
 export STUB_LOG="$BATS_TEST_TMPDIR/claude-calls.log"
 mkdir -p "$STUB_BIN"
 cat > "$STUB_BIN/claude" <<'STUB'
#!/bin/bash
echo "$*" >> "$STUB_LOG"
prompt=$(cat)
case "$prompt" in
 *"Derive a concise"*)
   printf '%s\n' "${STUB_TITLES:-Order Status Transition}" ;;
 *"deciding whether"*)
   echo "${STUB_MATCH:-NEW}" ;;
 *"technical documentation writer"*)
   title=$(printf '%s\n' "$prompt" | sed -n 's/^- Start with a # heading using the title: //p')
   printf '# %s\n\nGenerated for the staged change.\n' "$title" ;;
esac
STUB
 chmod +x "$STUB_BIN/claude"
 export PATH="$STUB_BIN:$PATH"
}
