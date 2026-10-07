#!/bin/bash
# Where the hook runs and what the triggering git commit command does.
# Sourced by pre-commit-documentation.sh — not executed directly.
#
# Contexts:
#   - Claude Code PreToolUse hook: tool-call JSON on stdin; .tool_input.command is the Bash command.
#   - Native git pre-commit hook (terminal, IntelliJ, VS Code, ...): git sets GIT_INDEX_FILE.
#     stdin belongs to git (e.g. `git commit -F -`) and is never read.
#   - Manual run: stdin is a tty, or empty.

# Return 0 when this may be a Claude Code hook, i.e. stdin may carry tool-call JSON.
is_claude_hook_context() {
 [ -z "${GIT_INDEX_FILE:-}" ] && [ ! -t 0 ]
}

# Print the Bash command of the Claude Code tool call read from stdin (JSON).
# Prints nothing when stdin is empty or not tool-call JSON. Requires jq.
read_claude_tool_command() {
 jq -r '.tool_input.command // ""' 2>/dev/null
}

# ── Commit command parser ────────────────────────────────────────────────────
# One Perl program answers every question about a shell command that may run git commit.
# Usage: printf '%s' "<command>" | perl -e "$COMMIT_COMMAND_PARSER" <query>
# Exits 1 (printing nothing) when the command does not run git commit. Queries:
#   is-commit       exit 0 for a real commit (not --dry-run / --help / -h)
#   message         print the commit message (heredoc body, or all -m/--message values)
#   staging-reason  print why the command stages files itself, or nothing
#   target-dir      print the directory the commit runs in, from cd/pushd before it and
#                   git -C (empty → the starting directory); exit 2 when it cannot be told
# (read -d '' returns 1 at end of input, which is expected here.)
read -r -d '' COMMIT_COMMAND_PARSER <<'PERL' || true
use strict;
use warnings;

my $query = shift @ARGV;
my $cmd = do { local $/; <STDIN> };
$cmd = '' unless defined $cmd;

# Mask heredocs and quoted strings with same-length filler: words inside a commit message
# can then never be mistaken for commands, and offsets still line up with $cmd.
my $masked = $cmd;
my $fill = sub { 'Q' x length $_[0] };
$masked =~ s/(<<-?\s*(['"]?)(\w+)\2[^\n]*\n.*?\n[ \t]*\3[ \t]*(?=\n|$))/$fill->($1)/gse;
$masked =~ s/("(?:[^"\\]|\\.)*")/$fill->($1)/gse;
$masked =~ s/('[^']*')/$fill->($1)/ge;

# "git" as a command word (at the start, or after a separator or shell keyword, optionally
# after VAR=value assignments), then git's global options, then the "commit" subcommand.
my $global_option = qr/-[Cc]\s+\S+|--(?:git-dir|work-tree|namespace)(?:=|\s+)\S+
                      |--no-pager|-P|--no-replace-objects|--literal-pathspecs|--no-optional-locks/x;
$masked =~ /(?:^|[;&|({\n])\s*(?:(?:then|do|else|time|!)\s+)?(?:\w+=\S*\s+)*
            git(?:\s+(?:$global_option))*\s+commit(?![\w-])/x
  or exit 1;
my ($commit_start, $commit_end) = ($-[0], $+[0]);

# The commit's arguments run up to the next separator: && || ; | ) or newline.
my ($masked_args) = substr($masked, $commit_end) =~ /^((?:(?!&&|\|\||[;|)\n]).)*)/s;
my $args   = substr($cmd, $commit_end, length $masked_args);   # original text, quotes intact
my $before = substr($masked, 0, $commit_start);
my @words  = grep { length } split /\s+/, $masked_args;

if ($query eq 'is-commit') {
  # --dry-run / --help / -h only print; nothing is committed.
  exit((grep { /^(?:--dry-run|--help|-h)$/ } @words) ? 1 : 0);
}

if ($query eq 'message') {
  # Heredoc form: -m "$(cat <<'EOF' ... EOF)" or -F - <<EOF ... EOF
  if ($args =~ /<<-?\s*(['"]?)(\w+)\1[^\n]*\n(.*?)\n[ \t]*\2[ \t]*(?:\n|$)/s) { print $3; exit }

  # -m/--message: repeatable, quoted or bare, also at the end of a flag cluster like -am
  my @parts;
  while ($args =~ /(?:^|\s)(?:-[a-zA-Z]*m|--message)(?:=|\s*)(?:"((?:[^"\\]|\\.)*)"|'([^']*)'|([^\s;&|]+))/g) {
    my $value = defined $1 ? $1 : defined $2 ? $2 : $3;
    $value =~ s/\\(["\\\$`])/$1/g if defined $1;
    push @parts, $value;
  }
  print join("\n\n", @parts);
  exit;
}

if ($query eq 'target-dir') {
  # Literal value of a shell word taken from the original command: bare, '...' or "..."
  # without expansions, with ~ expanded. undef when it depends on the shell at run time.
  my $literal = sub {
    my ($word) = @_;
    my $value;
    if    ($word =~ /^'([^']*)'$/)            { $value = $1 }
    elsif ($word =~ /^"([^"\$`\\]*)"$/)       { $value = $1 }
    elsif ($word =~ /^([^\s'"\$`\\*?\[-][^\s'"\$`\\*?\[]*)$/) { $value = $1 }
    else                                      { return undef }
    $value =~ s{^~(?=/|$)}{$ENV{HOME}} if $word !~ /^'/;
    return $value;
  };

  # Directory changes in effect when git commit starts, in order.
  my @dirs;
  while ($before =~ /(?:^|[;&|({\n])\s*(?:(?:then|do|else)\s+)?(cd|pushd|popd)\b([^;&|)\n]*)/g) {
    my ($builtin, $arg) = ($1, substr($cmd, $-[2], $+[2] - $-[2]));
    $arg =~ s/^\s+|\s+$//g;
    exit 2 if $builtin eq 'popd';
    if ($arg eq '') { push @dirs, $ENV{HOME}; next }                # plain cd → $HOME
    my $dir = $literal->($arg);
    exit 2 unless defined $dir;                                     # cd -, cd $X, cd -P x, ...
    push @dirs, $dir;
  }
  # A ")" before the commit may close a subshell whose cd no longer applies.
  exit 2 if @dirs && $before =~ /\)/;

  # git -C <dir> options on the commit itself; --git-dir/--work-tree are not followed.
  my $git_part = substr($masked, $commit_start, $commit_end - $commit_start);
  exit 2 if $git_part =~ /--(?:git-dir|work-tree)\b/;
  while ($git_part =~ /(?:^|\s)-C\s+(\S+)/g) {
    my $dir = $literal->(substr($cmd, $commit_start + $-[1], $+[1] - $-[1]));
    exit 2 unless defined $dir;
    push @dirs, $dir;
  }

  # Each relative directory is resolved against the previous one.
  my $path = '';
  for my $dir (@dirs) {
    $path = ($dir =~ m{^/} || $path eq '') ? $dir : "$path/$dir";
  }
  print $path;
  exit;
}

if ($query eq 'staging-reason') {
  if ($before =~ /\bgit\s+(add|rm|mv|stage|reset|restore|stash|apply|checkout)\b/) {
    print "git $1 runs before git commit in the same command"; exit;
  }

  my %takes_value = map { $_ => 1 } qw(-m -F -C -c -t --author --date --fixup --squash --cleanup
    --trailer --file --message --template --reuse-message --reedit-message);
  my %stages = map { $_ => 1 } qw(--all --include --only --patch --interactive);

  for (my $i = 0; $i < @words; $i++) {
    my $w = $words[$i];
    if ($w =~ /^\d*[<>]/) { $i++ if $w =~ /^\d*[<>]+&?$/; next }     # redirections
    if ($w eq '--') { print "files named on git commit" if $i < $#words; exit }
    if ($w =~ /^--/) {
      my ($name) = split /=/, $w, 2;
      if ($stages{$name}) { print "$name on git commit"; exit }
      $i++ if $takes_value{$w};
      next;
    }
    if ($w =~ /^-(.+)$/) {                                             # short-flag cluster, e.g. -am
      my @flags = split //, $1;
      for my $k (0 .. $#flags) {
        my $c = $flags[$k];
        if ($c =~ /[aiop]/) { print "-$c on git commit"; exit }
        if ($c =~ /[mFCctuS]/) {                                         # rest of cluster is its value
          $i++ if $k == $#flags && $c =~ /[mFCct]/;                      # ...or the next word is
          last;
        }
      }
      next;
    }
    print "files named on git commit"; exit;
  }
}
PERL

# Return 0 if <command> runs a real git commit (not commit-tree, --dry-run, --help, ...).
is_git_commit_command() {
 printf '%s' "$1" | perl -e "$COMMIT_COMMAND_PARSER" is-commit
}

# Print the commit message of the git commit in <command>.
# Prints "(commit message not available)" when there is none — always the case for a
# native git hook, where the message does not exist yet. .git/COMMIT_EDITMSG is deliberately
# NOT used: before the commit runs it still holds the previous commit's message.
commit_message_from_command() {
 local msg=""
 [ -n "$1" ] && msg=$(printf '%s' "$1" | perl -e "$COMMIT_COMMAND_PARSER" message)
 echo "${msg:-(commit message not available)}"
}

# Print the directory the git commit in <command> runs in, as written in the command
# (relative paths are relative to where the command starts); empty → where it starts.
# Returns non-zero when it cannot be worked out.
commit_target_dir() {
 printf '%s' "$1" | perl -e "$COMMIT_COMMAND_PARSER" target-dir
}

# Return 0 if the git commit in <command> runs in the repository at <repo_root>.
# <start_dir> is where the command starts (the hook's working directory): the hook runs
# before the command, so a cd or git -C in it has not happened yet.
# Returns 1 when the commit runs elsewhere, or when its directory cannot be worked out
# (cd $VAR, cd -, a subshell, ...) — documenting the wrong repository is worse than none.
commit_runs_in_repo() {
 local command="$1" start_dir="$2" repo_root="$3" dir target_root
 dir=$(commit_target_dir "$command") || return 1
 target_root=$(cd "$start_dir" 2>/dev/null && cd "${dir:-.}" 2>/dev/null \
   && git rev-parse --show-toplevel 2>/dev/null) || return 1
 [ "$target_root" = "$repo_root" ]
}

# Print why <command> stages files as part of its git commit, or nothing if it doesn't.
# A PreToolUse hook runs before the whole command, so staging done by the same command
# (git add … && git commit, commit -a/-i/-o/-p, or paths on git commit) is invisible to it.
staging_in_commit_command() {
 [ -n "$1" ] || return 0
 printf '%s' "$1" | perl -e "$COMMIT_COMMAND_PARSER" staging-reason
}
