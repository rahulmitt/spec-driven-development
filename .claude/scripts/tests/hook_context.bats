#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Tests for lib/hook_context.sh: context detection and git commit command parsing.

load helpers/common

setup() {
 load_libs
}

# ── is_git_commit_command ────────────────────────────────────────────────────

@test "is_git_commit_command accepts plain and chained commits" {
 is_git_commit_command 'git commit -m "x"'
 is_git_commit_command 'cd /repo && git commit -m "x"'
 is_git_commit_command 'git status; git commit'
 is_git_commit_command 'GIT_AUTHOR_NAME=me git commit -m x'
}

@test "is_git_commit_command accepts git global options before commit" {
 is_git_commit_command 'git -C /repo commit -m x'
 is_git_commit_command 'git -c user.name=me commit -m x'
 is_git_commit_command 'git --no-pager commit -m x'
}

@test "is_git_commit_command rejects commands that only mention git commit" {
 run ! is_git_commit_command 'grep "git commit" notes.txt'
 run ! is_git_commit_command 'echo git commit'
 run ! is_git_commit_command 'git log --grep "git commit"'
 run ! is_git_commit_command 'git status'
}

@test "is_git_commit_command rejects commit-tree, --dry-run and --help" {
 run ! is_git_commit_command 'git commit-tree HEAD^{tree}'
 run ! is_git_commit_command 'git commit --dry-run'
 run ! is_git_commit_command 'git commit --help'
 run ! is_git_commit_command 'git commit -h'
}

# ── commit_message_from_command ──────────────────────────────────────────────

@test "commit_message_from_command reads -m, repeated -m and -am" {
 run commit_message_from_command 'git commit -m "Add order endpoint"'
 [ "$output" = "Add order endpoint" ]

 run commit_message_from_command 'git commit -m "first" -m "second"'
 [ "$output" = "$(printf 'first\n\nsecond')" ]

 run commit_message_from_command "git commit -am 'all tracked'"
 [ "$output" = "all tracked" ]
}

@test "commit_message_from_command reads --message= and unescapes quotes" {
 run commit_message_from_command 'git commit --message="eq form"'
 [ "$output" = "eq form" ]

 run commit_message_from_command 'git commit -m "say \"hi\""'
 [ "$output" = 'say "hi"' ]
}

@test "commit_message_from_command reads a heredoc message" {
 local cmd
 cmd=$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
Refactor docs hook

Don't break "quotes".
EOF
)"
OUTER
)
 run commit_message_from_command "$cmd"
 [ "$output" = "$(printf 'Refactor docs hook\n\nDon'"'"'t break "quotes".')" ]
}

@test "commit_message_from_command falls back when there is no message" {
 run commit_message_from_command ""
 [ "$output" = "(commit message not available)" ]

 run commit_message_from_command "git commit --amend --no-edit"
 [ "$output" = "(commit message not available)" ]
}

# ── staging_in_commit_command ────────────────────────────────────────────────

@test "staging_in_commit_command reports staging before the commit" {
 run staging_in_commit_command 'git add . && git commit -m "x"'
 [ "$output" = "git add runs before git commit in the same command" ]
}

@test "staging_in_commit_command reports -a, --all and flag clusters" {
 run staging_in_commit_command 'git commit -a -m x'
 [ "$output" = "-a on git commit" ]

 run staging_in_commit_command 'git commit -am x'
 [ "$output" = "-a on git commit" ]

 run staging_in_commit_command 'git commit --all -m x'
 [ "$output" = "--all on git commit" ]
}

@test "staging_in_commit_command reports paths named on the commit" {
 run staging_in_commit_command 'git commit -m "x" src/A.java'
 [ "$output" = "files named on git commit" ]

 run staging_in_commit_command 'git commit -m "x" -- src/A.java'
 [ "$output" = "files named on git commit" ]
}

@test "staging_in_commit_command ignores redirections, pipes and message text" {
 run staging_in_commit_command 'git commit -m "x" 2>&1 | tail -5'
 [ -z "$output" ]

 run staging_in_commit_command 'git commit -m "x" > /tmp/out'
 [ -z "$output" ]

 run staging_in_commit_command 'git commit -m "do not git add this"'
 [ -z "$output" ]

 run staging_in_commit_command 'git commit -F msg.txt'
 [ -z "$output" ]
}

# ── is_claude_hook_context ───────────────────────────────────────────────────

@test "is_claude_hook_context is false for a native git hook" {
 GIT_INDEX_FILE=.git/index run is_claude_hook_context < /dev/null
 [ "$status" -ne 0 ]
}

@test "is_claude_hook_context is true for piped stdin without GIT_INDEX_FILE" {
 unset GIT_INDEX_FILE
 run is_claude_hook_context < /dev/null
 [ "$status" -eq 0 ]
}

@test "read_claude_tool_command extracts the Bash command from the JSON" {
 run read_claude_tool_command <<< '{"tool_input":{"command":"git commit -m \"x\""}}'
 [ "$output" = 'git commit -m "x"' ]

 run read_claude_tool_command < /dev/null
 [ -z "$output" ]
}

# ── commit_target_dir ────────────────────────────────────────────────────────

@test "commit_target_dir is empty when the commit runs where the command starts" {
 run commit_target_dir 'git commit -m "x"'
 [ "$status" -eq 0 ]
 [ -z "$output" ]

 run commit_target_dir 'git status && git commit -m "cd elsewhere"'
 [ -z "$output" ]
}

@test "commit_target_dir follows cd, pushd and git -C in order" {
 run commit_target_dir 'cd /tmp/other && git commit -m x'
 [ "$output" = "/tmp/other" ]

 run commit_target_dir 'cd sub; cd deeper && git -C more commit -m x'
 [ "$output" = "sub/deeper/more" ]

 run commit_target_dir 'pushd "/tmp/my dir" && git commit -m x'
 [ "$output" = "/tmp/my dir" ]

 run commit_target_dir 'git -C /abs commit -m x'
 [ "$output" = "/abs" ]
}

@test "commit_target_dir expands ~ and a plain cd to HOME" {
 run commit_target_dir 'cd ~/projects/x && git commit -m x'
 [ "$output" = "$HOME/projects/x" ]

 run commit_target_dir 'cd && git commit -m x'
 [ "$output" = "$HOME" ]
}

@test "commit_target_dir fails when the directory depends on the shell at run time" {
 run commit_target_dir 'cd $REPO && git commit -m x'
 [ "$status" -eq 2 ]

 run commit_target_dir 'cd - && git commit -m x'
 [ "$status" -eq 2 ]

 run commit_target_dir '(cd /tmp/x); git commit -m x'
 [ "$status" -eq 2 ]

 run commit_target_dir 'git --git-dir=/x/.git commit -m x'
 [ "$status" -eq 2 ]
}

@test "commit_target_dir ignores cd in a quoted commit message" {
 run commit_target_dir 'git commit -m "x; cd /tmp"'
 [ -z "$output" ]
}

# ── commit_runs_in_repo ──────────────────────────────────────────────────────

@test "commit_runs_in_repo tells this repo, a subdirectory and another repo apart" {
 local repo="$BATS_TEST_TMPDIR/this" other="$BATS_TEST_TMPDIR/other"
 git init -q "$repo" && git init -q "$other" && mkdir -p "$repo/src"
 repo=$(git -C "$repo" rev-parse --show-toplevel)

 commit_runs_in_repo 'git commit -m x' "$repo" "$repo"
 commit_runs_in_repo 'cd src && git commit -m x' "$repo" "$repo"
 run ! commit_runs_in_repo "cd $other && git commit -m x" "$repo" "$repo"
 run ! commit_runs_in_repo "git -C $other commit -m x" "$repo" "$repo"
 run ! commit_runs_in_repo 'cd missing-dir && git commit -m x' "$repo" "$repo"
}
