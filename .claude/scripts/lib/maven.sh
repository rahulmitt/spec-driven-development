#!/bin/bash
# Maven project layout helpers for the documentation hook.
# Sourced by pre-commit-documentation.sh — not executed directly.

# Print the top-level <module> paths declared in <dir>/pom.xml, one per line.
# Empty output → single-module project (or no pom.xml).
# XML comments and <profiles> are ignored; modules outside the repo (../x) are skipped.
maven_modules() {
 local pom="$1/pom.xml"
 [ -f "$pom" ] || return 0
 perl -0777 -ne '
   s/<!--.*?-->//gs;
   s/<profiles>.*?<\/profiles>//gs;
   while (/<module>\s*([^<]+?)\s*<\/module>/g) { my $m = $1; $m =~ s{/+$}{}; print "$m\n" unless $m =~ /^\.\./ }
 ' "$pom"
}

# Print the project name for <dir>: the artifactId of <dir>/pom.xml, else the directory name.
project_name() {
 local dir="$1" name=""
 if [ -f "$dir/pom.xml" ]; then
   name=$(perl -0777 -ne '
     s/<!--.*?-->//gs;
     s/<(parent|dependencyManagement|dependencies|build|profiles|reporting|plugins)>.*?<\/\1>//gs;
     print $1 if /<artifactId>\s*([^<\s]+)\s*<\/artifactId>/;
   ' "$dir/pom.xml")
 fi
 echo "${name:-$(basename "$dir")}"
}
