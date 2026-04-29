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

printf 'ok - existing branch worktree\n'
