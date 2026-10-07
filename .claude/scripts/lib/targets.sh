#!/bin/bash
# Documentation targets: which docs folder each part of the staged change is documented in.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
#   - Single-module (root pom.xml has no <modules>, or no pom.xml at all):
#       all staged changes → <repo>/docs/technical/
#   - Multi-module Maven (root pom.xml declares <modules>):
#       changes inside a module          → <module>/docs/technical/
#       changes outside every module     → <repo>/docs/technical/  (root pom, CI config, ...)

# Parallel arrays, one entry per target with staged changes.
DOC_TARGET_DIRS=()
DOC_TARGET_NAMES=()
DOC_TARGET_DIFFS=()

# Add a target unless its diff is empty. Args: $1 docs folder, $2 project name, $3 staged diff
add_doc_target() {
 [ -n "$3" ] || return 0
 DOC_TARGET_DIRS+=("$1")
 DOC_TARGET_NAMES+=("$2")
 DOC_TARGET_DIFFS+=("$3")
}

# Fill the DOC_TARGET_* arrays for the repo at <repo_root> (the current directory).
# Generated docs are excluded from every diff so they don't feed back into the prompts.
collect_doc_targets() {
 local repo_root="$1" module
 local root_excludes=(":(exclude)$DOCS_SUBDIR")

 for module in $(maven_modules "$repo_root"); do
   root_excludes+=(":(exclude)$module")
   add_doc_target "$repo_root/$module/$DOCS_SUBDIR" "$(project_name "$repo_root/$module")" \
     "$(staged_diff_capped "$module" ":(exclude)$module/$DOCS_SUBDIR")"
 done

 # Single-module: everything. Multi-module: whatever lies outside the declared modules.
 add_doc_target "$repo_root/$DOCS_SUBDIR" "$(project_name "$repo_root")" \
   "$(staged_diff_capped . "${root_excludes[@]}")"
}

# Stage every doc listed in <written_list>, then empty the list.
stage_written_docs() {
 local written_list="$1" file
 [ -s "$written_list" ] || return 0
 while IFS= read -r file; do
   git add "$file" && echo "Staged: $file"
 done < "$written_list"
 : > "$written_list"
}

# Document all targets, DOC_PARALLEL at a time, staging each batch's docs when it finishes.
# Each job's output is buffered in <work_dir> and printed in target order.
# Plain `wait` per batch (not `wait -n`) keeps this compatible with macOS bash 3.2.
run_doc_targets_in_batches() {
 local work_dir="$1" written_list="$1/written"
 local count=${#DOC_TARGET_DIRS[@]} start=0 end i

 while [ "$start" -lt "$count" ]; do
   end=$((start + DOC_PARALLEL))
   [ "$end" -gt "$count" ] && end=$count

   for ((i = start; i < end; i++)); do
     document_target "${DOC_TARGET_DIRS[i]}" "${DOC_TARGET_NAMES[i]}" "${DOC_TARGET_DIFFS[i]}" \
       "$written_list" > "$work_dir/log.$i" 2>&1 &
   done
   wait

   for ((i = start; i < end; i++)); do
     cat "$work_dir/log.$i"
   done
   stage_written_docs "$written_list"

   start=$end
 done
}
