# cc-launch

[中文说明](./README.zh-CN.md)

A Git worktree launcher with a single `ccl` entrypoint for creating, entering, and cleaning up worktrees, then launching `codex` or `claude` in the target directory.

## Install

For Zsh:

```bash
npm install -g cc-launch && echo 'eval "$(command ccl init zsh)"' >> ~/.zshrc && source ~/.zshrc
```

For Bash:

```bash
npm install -g cc-launch && echo 'eval "$(command ccl init bash)"' >> ~/.bashrc && source ~/.bashrc
```

## Usage

Run from any subdirectory inside a Git repository:

```bash
ccl
```

Menu interaction:

- Use `↑` / `↓` to move
- Press `Enter` to confirm
- Mouse wheel navigation and click-to-select are supported when the terminal reports mouse coordinates

Project config:

- `setup.sh` and `config.json` are stored in `~/.worktrees/<repo-name>/`
- On first run, the tool asks for the repository's main branch and writes it to `config.json`
- When creating worktrees later, the tool can either create a new task branch or check out an existing local or filtered remote branch that is not already used by another worktree
- For new task branches, the tool asks which branch to base the worktree on; the configured main branch is selected by default and can be accepted with `Enter`
- Deletion checks merge status against that configured main branch and accepts branches merged by merge commit, not just branches that `git branch -d` considers fully merged
- The delete menu includes clean linked worktrees plus local branches that are not checked out in any worktree, and labels each item as `merged` or `unmerged`
- Unmerged branches can still be deleted; `ccl` will warn and use `git branch -D` only after determining that the branch is not merged into the configured main branch

Interactive capabilities:

- New task: create `~/.worktrees/<repo-name>/<username>-<task-slug>` and a new `<username>/<task-slug>` branch
- Existing branch: create a worktree for a local branch, or search remote branches by substring and create a local tracking branch from a match
- Continue existing worktree: list all worktrees in the current repository, including the main working tree
- Delete a worktree or branch: show clean additional worktrees plus removable local branches, along with whether each one is merged into the configured main branch

Setup command:

- Run `ccl setup` to create or edit the project-level setup script
- The script is stored at `~/.worktrees/<repo-name>/setup.sh`
- It runs automatically after a new worktree is created, which is useful for steps like installing dependencies or copying `.env` files

## Development

Run the regression test suite with:

```bash
npm test
```
