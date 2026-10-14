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

tmpdir="$(mktemp -d /tmp/ccl-test-XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

case_home="$tmpdir/home"
main_repo="$tmpdir/project-main"
linked_worktree="$tmpdir/project-feature"

mkdir -p "$case_home"
mkdir -p "$main_repo"
cd "$main_repo"
git init -q -b main
git config user.name 'Test User'
git config user.email 'test@example.com'
printf 'hello\n' > README.md
git add README.md
git commit -q -m 'init'
git branch dev
git worktree add -q "$linked_worktree" -b test/feature dev
mkdir -p "$linked_worktree/nested/sub" "$main_repo/docs"

setup_dir="$case_home/.worktrees/project-main"
mkdir -p "$setup_dir"

run_setup_in() {
  local cwd="$1"
  local rc=0
  (
    cd "$cwd"
    export HOME="$case_home"
    source "$CORE_SCRIPT"
    repo_root=""
    current_worktree_root=""
    repo_name=""
    username=""
    worktree_repo_dir=""
    config_path=""
    main_branch=""
    repo_context_loaded=0
    run_setup_command
  ) >"$tmpdir/stdout.log" 2>"$tmpdir/stderr.log" || rc=$?
  printf '%s' "$rc"
}

# Case 1: run from a nested directory inside a linked worktree
cat > "$setup_dir/setup.sh" <<EOF
#!/usr/bin/env bash
echo "stdout-must-not-leak"
printf '%s\n' "\$PWD" > "$tmpdir/pwd-marker"
EOF

rc="$(run_setup_in "$linked_worktree/nested/sub")"
assert_eq "$rc" "0" "ccl setup should succeed when the setup script passes"
assert_eq "$(cat "$tmpdir/stdout.log")" "" "ccl setup must keep stdout empty because the shell wrapper evals it"
assert_eq "$(cat "$tmpdir/pwd-marker")" "$linked_worktree" "ccl setup should run the script at the current worktree root"

# Case 2: run from a nested directory inside the main worktree
rc="$(run_setup_in "$main_repo/docs")"
assert_eq "$rc" "0" "ccl setup should succeed from the main worktree"
assert_eq "$(cat "$tmpdir/pwd-marker")" "$main_repo" "ccl setup should run the script at the main worktree root"

# Case 3: the setup script's exit code is propagated
cat > "$setup_dir/setup.sh" <<'EOF'
#!/usr/bin/env bash
exit 42
EOF

rc="$(run_setup_in "$main_repo")"
assert_eq "$rc" "42" "ccl setup should propagate the setup script's exit code"

# Case 4: missing setup script fails with a hint
rm "$setup_dir/setup.sh"

rc="$(run_setup_in "$main_repo")"
[[ "$rc" != "0" ]] || die "ccl setup should fail when no setup script exists"
grep -q 'ccl setup --edit' "$tmpdir/stderr.log" || die "ccl setup failure should point to 'ccl setup --edit'"

printf 'ok - setup command\n'
