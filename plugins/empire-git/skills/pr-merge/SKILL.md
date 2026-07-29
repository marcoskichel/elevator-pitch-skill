---
name: pr-merge
description: >
  Gate then merge a single pull request safely. Use when the user says "merge
  this PR", "merge the PR", "land this", "ship this PR", "merge when green".
  Verifies CI is green (investigates and attempts a fix when red), rebases and
  resolves conflicts when the branch is behind, triages unresolved review
  threads intelligently (resolve, fix, or ask — never blindly block), then
  merges and deletes the branch. Fast-forwards the local base checkout (e.g.
  updates `master`) when it is checked out.
compatibility: Requires the gh CLI, git, and network access to GitHub.
model: sonnet
allowed-tools: Bash Read Glob Grep
argument-hint: "[--pr <number>] [--squash|--merge|--rebase] [--admin]"
---

# PR Merge

Merge one PR only after it is genuinely ready: CI green, no conflicts, review threads handled. Then merge and delete the head branch.

**User input:** $ARGUMENTS

CRITICAL: Never merge red CI, never bypass a failing gate with `--admin` unless the user explicitly asks, and never force-merge over unresolved actionable review feedback.

## Step 1 — Identify the PR

- Default: the PR for the current branch (`gh pr view --json number`).
- If the user named a number or URL, use that.

Capture context once:

```bash
gh pr view <pr> --json number,title,state,baseRefName,headRefName,mergeable,mergeStateStatus,reviewDecision,url
```

## Step 2 — Gate: CI

```bash
gh pr checks <pr>
```

- All passing → continue.
- Still running → `gh pr checks <pr> --watch` (or wait and re-check). Don't merge until resolved.
- Failing → do NOT merge. Investigate the failing run (use the `ci-investigation` skill if available), fix the cause, commit, push, and re-check. Re-run this step until green.

## Step 3 — Gate: conflicts / freshness

Read `mergeable` and `mergeStateStatus` from Step 1.

- `MERGEABLE` / clean → continue.
- `CONFLICTING`, or behind the base enough to need an update → rebase onto the base:

```bash
git fetch origin
git rebase origin/<baseRefName>
# resolve conflicts, then:
git push --force-with-lease
```

Resolve conflicts by understanding both sides, never by blindly taking one. If a worktree isn't already isolating this branch, prefer doing the rebase in one (`/empire-git:worktree-open`). Re-check CI after pushing.

## Step 4 — Gate: review threads

Fetch unresolved threads:

```bash
gh api graphql -f query='
query($owner:String!,$repo:String!,$pr:Int!){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$pr){
      reviewThreads(first:100){ nodes{
        id isResolved isOutdated path line
        comments(first:20){ nodes{ author{login} body } }
      } }
    }
  }
}' -F owner=<owner> -F repo=<repo> -F pr=<pr> \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved==false)'
```

Triage each unresolved thread — be smart, not mechanical:

| Thread                                                | Action                                       |
| ----------------------------------------------------- | -------------------------------------------- |
| Nit, already addressed, or acknowledged               | Resolve it (mutation below).                 |
| Real, in-scope issue                                  | Fix the code, push, then resolve the thread. |
| Ambiguous, contentious, design-level, or out of scope | Ask the user. Do not decide unilaterally.    |

Resolve a thread once handled:

```bash
gh api graphql -f query='mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' -F id=<threadId>
```

Block the merge only on threads that are real and unhandled. Outdated threads on code that no longer exists are safe to resolve.

## Step 5 — Merge

Detect the allowed merge methods:

```bash
gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed
```

- Honor an explicit `--squash` / `--merge` / `--rebase` from the user.
- Otherwise default to squash when allowed, then merge commit, then rebase.

Merge and delete the now-orphaned head branch:

```bash
gh pr merge <pr> --squash --delete-branch
```

If branch protection blocks the merge (missing required approvals, etc.), report exactly what's missing. Use `--admin` only if the user explicitly authorized bypassing.

## Step 6 — Update the local base checkout

The merge landed on the remote base branch. If that branch is checked out locally (the main working tree or a worktree), fast-forward it so local work sees the merge — e.g. update `master` after merging into it.

Find a local checkout of the base branch:

```bash
git worktree list --porcelain \
  | awk -v b="<baseRefName>" '/^worktree /{p=substr($0,10)} /^branch /{if ($2=="refs/heads/"b) print p}'
```

If a path is found, fast-forward only — never clobber local commits or a dirty tree:

```bash
git -C <path> fetch origin <baseRefName>
git -C <path> merge --ff-only origin/<baseRefName>
```

If the checkout is dirty or can't fast-forward, skip it and warn — leave the working tree untouched. If the base branch is checked out nowhere locally, do nothing.

## Step 7 — Report

State the outcome: PR merged (method), branch deleted, local base fast-forwarded (if it was checked out). Note anything deferred to the user.

## Why

A merge is the one irreversible step in the PR lifecycle. Gating on CI, conflicts, and live feedback prevents landing broken or contested work. Fast-forwarding the local base checkout keeps local work in sync with what just landed.
