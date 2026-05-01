---
name: worktree-merge
description: Merge a worktree's branch into another branch using git merge. Use this when the user wants to combine a worktree branch into a parent branch, batch small fixes into one branch, or fold sub-feature branches back together. This is always a real git merge — for pushing to remote, use `/empire-git:worktree-close --push` instead. Also triggers for `/empire-git:worktree-merge [branch] --into <target> [--no-close]`.
model: sonnet
allowed-tools: Bash Read Glob Grep
argument-hint: "<branch> --into <target> [--no-close]"
---

# Worktree Merge

Merge a worktree's branch into a target branch. This is always a real `git merge` — the target is a local branch where the worktree's commits get folded in.

**User input:** $ARGUMENTS

## Step 1 — Determine the source branch

**If currently inside a worktree** (not the main working tree):

- Use the current worktree's branch.

**If `$ARGUMENTS` specifies a branch name or worktree path:**

- Use that. Verify it has an associated worktree via `git worktree list --porcelain`.

**If neither:**

- List all worktrees with `git worktree list` and ask the user which one to merge.

Record the worktree path and branch name for subsequent steps.

## Step 2 — Determine the target branch

The target is where the source branch's commits will be merged into.

**If `--into <target>` is in the arguments:** use that branch.

**If no target is specified:** ask the user which branch to merge into. Common choices:

- `main` — the default branch
- A parent feature branch (e.g., `feat/auth` when merging `feat/auth-nav`)

The target branch must be checked out somewhere — either in the main working tree or in another worktree. Find it:

```bash
git worktree list --porcelain
```

If the target branch isn't checked out anywhere, check it out in the main working tree first.

## Step 3 — Pre-flight checks

### Clean working tree

```bash
git -C "<source-worktree-path>" status --porcelain
```

If there are uncommitted changes, **stop** and tell the user:

> This worktree has uncommitted changes. Please commit them first (e.g., run `/commit`), then re-run `/empire-git:worktree-merge`.

### Commits to merge

```bash
git -C "<source-worktree-path>" log --oneline <target>..<source-branch>
```

If there are no commits ahead of the target, **stop**:

> Branch `<source>` has no new commits relative to `<target>`. Nothing to merge.

## Step 4 — Perform the merge

```bash
git -C "<target-worktree-path>" merge "<source-branch>" --no-ff
```

The `--no-ff` flag preserves the branch history as a merge commit, which makes the history easier to read and revert if needed.

**If merge conflicts occur:**

1. List the conflicting files:
   ```bash
   git -C "<target-worktree-path>" diff --name-only --diff-filter=U
   ```
2. Report the conflicts clearly to the user.
3. **Stop.** Merge conflicts need human judgment — auto-resolving risks silently introducing bugs. Tell the user to resolve conflicts in the target worktree, then run `/empire-git:worktree-close` on the source worktree when ready.

**On success**, print:

```
Merged '<source-branch>' into '<target-branch>'.
```

## Step 5 — Cleanup (unless --no-close)

If `--no-close` was in the arguments, skip this step and just print the result. The user may want to keep the source worktree around for further work.

Otherwise, present the same cleanup options as `/empire-git:worktree-close`:

1. **Remove worktree only** — keeps the branch around in case it's needed
2. **Remove worktree + delete branch** — full cleanup, since the commits now live in the target branch
3. **Keep everything** — do nothing

After a successful merge, default to option 2 — the branch's commits are now in the target, so the source branch has served its purpose.

Execute the chosen option:

```bash
# Option 1 or 2: remove the worktree
git worktree remove "<source-worktree-path>"

# Option 2 only: also delete the branch (safe delete)
git branch -d "<source-branch>"
```

Then prune:

```bash
git worktree prune
```

Print a summary of what was done.

## When to use this

**Batching small fixes:** Several small worktree branches (typo, dep bump, color tweak) merged locally into one branch before opening a single PR:

```
/empire-git:worktree-merge fix/typo --into feat/cleanup
/empire-git:worktree-merge fix/deps --into feat/cleanup
/empire-git:worktree-merge fix/color --into feat/cleanup
# Then open one PR from feat/cleanup
```

**Branch decomposition:** Sub-branches merged back into a parent feature branch:

```
/empire-git:worktree-merge feat/auth-nav --into feat/auth
/empire-git:worktree-merge feat/auth-table --into feat/auth
# Then open one PR from feat/auth
```

## Guiding principles

**This skill does one thing: git merge.** For pushing to remote, use `/empire-git:worktree-close --push`. For opening PRs, use the user's own PR workflow. Keeping these concerns separate avoids conflicts with existing conventions.

**Merge conflicts need human judgment.** When conflicts occur, clearly list the affected files and let the user decide. Attempting to auto-resolve risks silently introducing bugs.

**Use `git branch -d` (safe delete), not `-D`.** If the safe delete fails after a merge, something unexpected happened — surface it rather than force through.
