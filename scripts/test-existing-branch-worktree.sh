#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
CORE_SCRIPT="$REPO_DIR/ccl-core.sh"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"

  if [[ "$actual" != "$expected" ]]; then
    die "$message
expected: $expected
actual:   $actual"
  fi
}

assert_success() {
  local status="$1"
  local message="$2"

  if [[ "$status" -ne 0 ]]; then
    die "$message"
  fi
}

assert_failure() {
  local status="$1"
  local message="$2"

  if [[ "$status" -eq 0 ]]; then
    die "$message"
  fi
}

tmpdir="$(mktemp -d /tmp/ccl-existing-branch-test-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/project-main"
remote_repo="$tmpdir/project-origin.git"
worktree_dir="$tmpdir/worktrees/project-main"

mkdir -p "$repo" "$worktree_dir"
cd "$repo"
git init -q -b main
git config user.name 'Test User'
git config user.email 'test@example.com'

printf 'base\n' > README.md
git add README.md
git commit -q -m 'init'

git branch feature/existing-work
git init -q --bare "$remote_repo"
git remote add origin "$remote_repo"
git push -q -u origin main

git switch -q -c feature/remote-work
printf 'remote\n' > remote.txt
git add remote.txt
git commit -q -m 'remote branch'
git push -q -u origin feature/remote-work
git switch -q main
git branch -D feature/remote-work >/dev/null

source "$CORE_SCRIPT"
worktree_repo_dir="$worktree_dir"

created_path="$(create_worktree_for_existing_branch feature/existing-work 2>/dev/null)"
assert_eq "$created_path" "$worktree_dir/feature-existing-work" "existing branch worktree should use a branch-derived path"
assert_eq "$(git -C "$created_path" branch --show-current)" "feature/existing-work" "existing branch should be checked out in the new worktree"

set +e
(create_worktree_for_existing_branch feature/existing-work >/dev/null 2>&1)
duplicate_status=$?
set -e
assert_failure "$duplicate_status" "creating a second worktree for an in-use branch should fail"

set +e
(create_worktree_for_existing_branch missing/branch >/dev/null 2>&1)
missing_status=$?
set -e
assert_failure "$missing_status" "creating a worktree for a missing local branch should fail"

set +e
build_existing_branch_candidates
candidate_status=$?
set -e
assert_success "$candidate_status" "existing branch candidates should build successfully"

for branch in "${EXISTING_BRANCH_NAMES[@]}"; do
  [[ "$branch" != "feature/existing-work" ]] || die "in-use branches should not be listed as existing-branch candidates"
done

remote_candidate_found=0
for branch in "${EXISTING_BRANCH_NAMES[@]}"; do
  if [[ "$branch" == "origin/feature/remote-work" ]]; then
    remote_candidate_found=1
  fi
done
assert_eq "$remote_candidate_found" "0" "remote branches should not be listed before filtering"

set +e
build_remote_branch_candidates "remote-work"
remote_candidate_status=$?
set -e
assert_success "$remote_candidate_status" "filtered remote branch candidates should build successfully"

remote_candidate_found=0
for branch in "${REMOTE_BRANCH_NAMES[@]}"; do
  if [[ "$branch" == "origin/feature/remote-work" ]]; then
    remote_candidate_found=1
  fi
done
assert_eq "$remote_candidate_found" "1" "matching remote branches should be listed after filtering"

build_remote_branch_candidates "does-not-exist"
assert_eq "${#REMOTE_BRANCH_NAMES[@]}" "0" "non-matching remote branch filters should return no candidates"

remote_path="$(create_worktree_for_existing_branch origin/feature/remote-work 2>/dev/null)"
assert_eq "$remote_path" "$worktree_dir/feature-remote-work" "remote branch worktree should use the derived local branch path"
assert_eq "$(git -C "$remote_path" branch --show-current)" "feature/remote-work" "remote branch should create and check out a local tracking branch"

upstream="$(git -C "$remote_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}')"
assert_eq "$upstream" "origin/feature/remote-work" "remote branch worktree should track the selected remote branch"

printf 'ok - existing branch worktree\n'
