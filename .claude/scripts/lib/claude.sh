#!/bin/bash
# Claude CLI calls and validation of their raw output for the documentation hook.
# Sourced by pre-commit-documentation.sh — not executed directly.

# Keep the nested sessions to plain text generation: no tools, no MCP servers, and only user
# settings, so this project's hooks and permissions are not loaded into them.
CLAUDE_ISOLATION_ARGS=(--tools "" --strict-mcp-config --setting-sources user)

# Send the prompt on stdin to Claude and print its plain-text answer.
# Args: $1 model (empty → CLI default). Killed after DOC_CALL_TIMEOUT seconds.
ask_claude() {
 local model="$1"
 local args=(-p --output-format text "${CLAUDE_ISOLATION_ARGS[@]}")
 [ -n "$model" ] && args+=(--model "$model")
 run_with_timeout claude "${args[@]}" 2>/dev/null
}

# ask_claude with the fast model (DOC_FAST_MODEL), for short classification answers.
ask_claude_fast() {
 ask_claude "$DOC_FAST_MODEL"
}

# Filter a raw title answer down to usable titles, one per line (max 3).
# Strips list markers, markdown, quotes, a "Title:" prefix and trailing punctuation;
# drops preamble lines ("Here are the titles:") and anything that is not a 1-8 word
# Title Case phrase of at most 80 characters.
parse_titles() {
 grep -vE ':[[:space:]]*$' \
   | sed -E 's/^[[:space:]]*([-*]|[0-9]+[.)])[[:space:]]+//; s/[*_`"#]//g; s/^[Tt]itle[[:space:]]*:[[:space:]]*//; s/[[:space:].:;!?,]+$//; s/^[[:space:]]+//' \
   | awk '
       NF < 1 || NF > 8 || length($0) > 80 { next }
       {
         ok = 1
         for (i = 1; i <= NF; i++)
           if ($i !~ /^[A-Z0-9]/ && $i !~ /^(a|an|and|as|at|by|for|in|of|on|or|the|to|via|with)$/) { ok = 0; break }
         if (ok) print
       }' \
   | head -3
}

# Filter a raw similarity answer to a bare .md filename, or print nothing ("NEW", chatter).
parse_doc_filename() {
 tr -d '"`'"'" | awk 'NF { print $1; exit }' | grep -E '^[A-Za-z0-9._-]+\.md$'
}

# Normalise a raw document answer: drop any preamble before the first "# " heading,
# unwrap a code fence around the whole document (and chatter after it), trim trailing blanks.
# Callers must still check that the result starts with "# ".
parse_markdown_doc() {
 awk '
   { l[NR] = $0 }
   END {
     s = 1; e = NR
     while (s <= e && l[s] !~ /^(# |```)/) s++
     if (s <= e && l[s] ~ /^```/) {
       s++
       while (e > s && l[e] !~ /^```[[:space:]]*$/) e--
       e--
       while (s <= e && l[s] !~ /^# /) s++
     }
     while (e >= s && l[e] ~ /^[[:space:]]*$/) e--
     for (i = s; i <= e; i++) print l[i]
   }'
}
