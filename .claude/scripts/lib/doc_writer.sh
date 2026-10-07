#!/bin/bash
# Generates or updates the technical doc(s) for one documentation target.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
# Naming strategy (per target):
#   1. Ask Claude for a title (up to 3 for unrelated concerns) from the staged diff + commit message
#   2. Slugify it to a filename (e.g. "OAuth Token Refresh" → oauth-token-refresh.md)
#   3. That file exists → update it
#   4. Otherwise ask Claude for the semantically closest existing .md → update it, or create the new file
#   5. A doc is only written when Claude's output starts with a "# " heading
#
# Reads the global COMMIT_MSG set by the entry script.

# Turn a title into a kebab-case filename stem (lowercase, spaces→hyphens, specials stripped).
slugify_title() {
 echo "$1" \
   | tr '[:upper:]' '[:lower:]' \
   | sed 's/[^a-z0-9 ]//g' \
   | sed 's/  */ /g' \
   | sed 's/ /-/g' \
   | sed 's/^-//;s/-$//'
}

# Print the doc file to write for <title>: the file named after the title if it exists,
# else an existing doc Claude judges to cover the same topic, else the new file.
# Args: $1 docs folder, $2 title, $3 project name, $4 staged diff
resolve_doc_file() {
 local doc_dir="$1" title="$2" project="$3" diff="$4"
 local new_file existing_names match
 new_file="$doc_dir/$(slugify_title "$title").md"

 if [ -f "$new_file" ]; then
   echo "$new_file"
   return
 fi

 existing_names=$(find "$doc_dir" -maxdepth 1 -name "*.md" -exec basename {} \; 2>/dev/null | tr '\n' ' ')
 if [ -n "$existing_names" ]; then
   match=$(prompt_similarity_check "$title" "$project" "$(echo "$diff" | head -80)" "$existing_names" \
     | ask_claude_fast | parse_doc_filename)
   if [ -n "$match" ] && [ -f "$doc_dir/$match" ]; then
     echo "Semantic match found: $match (updating instead of creating $(basename "$new_file"))" >&2
     echo "$doc_dir/$match"
     return
   fi
 fi

 echo "$new_file"
}

# Print the new content of <doc_file> for <title>; returns 1 if Claude's output is unusable.
# Args: $1 doc file (may not exist yet), $2 title, $3 project name, $4 staged diff
generate_doc() {
 local doc_file="$1" title="$2" project="$3" diff="$4"
 local existing_content="" doc
 [ -f "$doc_file" ] && existing_content=$(cat "$doc_file")

 doc=$(prompt_generate_doc "$title" "$project" "$COMMIT_MSG" "$diff" "$existing_content" \
   | ask_claude "" | parse_markdown_doc)

 [[ "$doc" == "# "* ]] || return 1
 echo "$doc"
}

# Replace <file> with <content> atomically: a killed hook leaves either the old or the new doc.
write_doc_atomically() {
 local file="$1" content="$2"
 echo "$content" > "$file.tmp.$$" && mv "$file.tmp.$$" "$file"
}

# Generate/update the docs for one target. Each written file is appended to <written_list>;
# the caller stages them (targets run concurrently and must not race on .git/index.lock).
# Args: $1 docs folder (absolute), $2 project name, $3 staged diff, $4 written-list file
document_target() {
 local doc_dir="$1" project="$2" diff="$3" written_list="$4"
 local titles title doc_file doc

 mkdir -p "$doc_dir"

 if ! time_budget_left; then
   echo "Warning: time budget exhausted, skipping docs for $project"
   return
 fi

 titles=$(prompt_derive_title "$project" "$COMMIT_MSG" "$diff" | ask_claude_fast | parse_titles)
 if [ -z "$titles" ]; then
   echo "Warning: could not derive documentation title for $project, skipping"
   return
 fi

 while IFS= read -r title; do
   [ -z "$title" ] && continue

   if ! time_budget_left; then
     echo "Warning: time budget exhausted, skipping \"$title\" ($project)"
     continue
   fi

   doc_file=$(resolve_doc_file "$doc_dir" "$title" "$project" "$diff")

   if ! time_budget_left; then
     echo "Warning: time budget exhausted, skipping \"$title\" ($project)"
     continue
   fi

   if ! doc=$(generate_doc "$doc_file" "$title" "$project" "$diff"); then
     echo "Warning: generated doc for \"$title\" is empty or malformed, not written"
     continue
   fi

   write_doc_atomically "$doc_file" "$doc" && echo "$doc_file" >> "$written_list"
 done <<< "$titles"
}
