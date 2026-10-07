#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# Tests for lib/git.sh and lib/maven.sh.

load helpers/common

setup() {
 load_libs
 make_repo
}

# ── staged_diff_capped ───────────────────────────────────────────────────────

@test "staged_diff_capped prints the whole diff when it fits" {
 echo "change" >> README.md
 git add README.md
 run staged_diff_capped .
 [[ "$output" == *"+change"* ]]
 [[ "$output" != *"[diff truncated"* ]]
}

@test "staged_diff_capped prints a stat and a truncated diff when too large" {
 DOC_MAX_DIFF_BYTES=2000
 seq 1 1000 > big.txt
 git add big.txt
 run staged_diff_capped .
 [[ "${lines[0]}" == *"big.txt"* ]]
 [[ "$output" == *"[diff truncated: showing "*" of "*" lines]"* ]]
 [ "${#output}" -le 2100 ]
}

@test "staged_diff_capped prints nothing when nothing is staged" {
 run staged_diff_capped .
 [ -z "$output" ]
}

# ── documented-tree marker ───────────────────────────────────────────────────

@test "the marker matches the staged tree it was recorded for, once" {
 echo "change" >> README.md
 git add README.md
 record_documented_tree
 consume_documented_tree_marker
 run ! consume_documented_tree_marker
}

@test "the marker does not match a different staged tree" {
 echo "change" >> README.md
 git add README.md
 record_documented_tree
 echo "more" >> README.md
 git add README.md
 run ! consume_documented_tree_marker
 [ ! -f "$(documented_tree_marker_path)" ]
}

# ── maven ────────────────────────────────────────────────────────────────────

@test "maven_modules lists modules, ignoring comments, profiles and ../ paths" {
 cat > pom.xml <<'POM'
<project>
 <artifactId>parent</artifactId>
 <modules>
   <module>orders</module>
   <module>billing/</module>
   <!-- <module>legacy</module> -->
   <module>../outside</module>
 </modules>
 <profiles><profile><modules><module>extra</module></modules></profile></profiles>
</project>
POM
 run maven_modules .
 [ "$output" = $'orders\nbilling' ]
}

@test "project_name reads the project's own artifactId, not the parent's" {
 mkdir svc
 cat > svc/pom.xml <<'POM'
<project>
 <parent><artifactId>parent-pom</artifactId></parent>
 <artifactId>order-service</artifactId>
</project>
POM
 run project_name svc
 [ "$output" = "order-service" ]
}

@test "project_name falls back to the directory name" {
 mkdir plain-dir
 run project_name plain-dir
 [ "$output" = "plain-dir" ]
}
