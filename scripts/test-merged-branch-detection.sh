#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
CORE_SCRIPT="$REPO_DIR/ccl-core.sh"

die() {
  printf '%s\n' "$*" >&2
  exit 1
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

run_branch_check() {
  local repo="$1"
  local branch="$2"

  (
    cd "$repo"
    source "$CORE_SCRIPT"
    main_branch="dev"
    branch_merged_into_main_branch "$branch"
  )
}

run_branch_delete() {
  local repo="$1"
  local branch="$2"

  (
    cd "$repo"
    source "$CORE_SCRIPT"
    main_branch="dev"

    if branch_merged_into_main_branch "$branch"; then
      git branch -d "$branch"
    else
      git branch -D "$branch"
    fi
  )
}

tmpdir="$(mktemp -d /tmp/ccl-merge-test-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

repo="$tmpdir/project-main"
mkdir -p "$repo"
cd "$repo"
git init -q -b dev
git config user.name 'Test User'
git config user.email 'test@example.com'

printf 'base\n' > README.md
git add README.md
git commit -q -m 'init'

git branch merged-via-merge-commit
git switch -q merged-via-merge-commit
printf 'merged change\n' >> README.md
git add README.md
git commit -q -m 'feature change'
git switch -q dev
git merge --no-ff -q merged-via-merge-commit -m 'Merge branch merged-via-merge-commit'

git branch unmerged-feature
git switch -q unmerged-feature
printf 'unmerged change\n' >> README.md
git add README.md
git commit -q -m 'unmerged change'
git switch -q dev

set +e
run_branch_check "$repo" merged-via-merge-commit
merged_status=$?
run_branch_check "$repo" unmerged-feature
unmerged_status=$?
set -e

assert_success "$merged_status" "branch_merged_into_main_branch should accept a branch merged through a merge commit"
assert_failure "$unmerged_status" "branch_merged_into_main_branch should reject a branch that has not been merged"

run_branch_delete "$repo" merged-via-merge-commit >/dev/null
assert_failure "$(git show-ref --verify --quiet refs/heads/merged-via-merge-commit; echo $?)" "merged branch should be deleted"

run_branch_delete "$repo" unmerged-feature >/dev/null
assert_failure "$(git show-ref --verify --quiet refs/heads/unmerged-feature; echo $?)" "unmerged branch should be force deleted after merge-status check"

printf 'ok - merged branch detection\n'
