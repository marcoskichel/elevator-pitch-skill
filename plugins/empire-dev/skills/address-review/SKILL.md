---
name: address-review
description: >
  Trigger when user says: "address review", "address the review", "address
  review comments", "address PR comments", "handle review comments", "fix
  review comments", "respond to the review", "reply to review comments",
  "resolve review comments", "address the feedback", "work through the review",
  "/empire-dev:address-review". Verifies every unresolved review comment
  adversarially, evaluates whether the reviewer's proposed change is the best
  fix, rechecks any alternative it prefers, implements accepted fixes in
  parallel, and replies to every comment in a direct tone. One compact TLDR
  confirmation gates all GitHub writes (push + replies).
compatibility: Requires the gh CLI and network access; dispatches subagents; PR head branch checked out locally.
allowed-tools: Bash Read Glob Grep Agent Workflow
---

<section id="overview">

Address PR review comments end to end: verify each one adversarially, pick the best fix (reviewer's proposal or a rechecked alternative), fix in parallel, reply directly.
Pipeline: resolve PR → collect unresolved threads → verify → evaluate fix → recheck alternatives → fix in parallel → TLDR gate → commit, push, reply.
Everything before the gate is local. The ONE confirmation covers commits, push, and replies.

</section>

<section id="target-detection">

- Resolve the target PR first. Signals, in order:
  - Explicit PR number or URL in the invocation
  - Open PR for the current branch: `gh pr view --json number,url,headRefName`
  - PR referenced earlier in the conversation
- Derive `OWNER`/`REPO` from the PR's `.url`, never from `gh repo view`.
- Fixes land on the PR head branch. If the checked-out branch ≠ `headRefName` → STOP and tell the user to check out the PR branch (or open its worktree) before rerunning.
- Run `git status --porcelain`. Uncommitted changes in the working tree → STOP and tell the user to commit or stash before rerunning.
- State the target in one line: `OWNER/REPO#PR @ <branch>`, then keep going. Confirm only when genuinely ambiguous.

</section>

<section id="collect-comments">

- Fetch unresolved review threads:

  ```bash
  gh api graphql -F owner="$OWNER" -F repo="$REPO" -F pr="$PR" -f query='
    query($owner:String!,$repo:String!,$pr:Int!){
      repository(owner:$owner,name:$repo){
        pullRequest(number:$pr){
          author{login}
          reviewThreads(first:100){
            pageInfo{hasNextPage endCursor}
            nodes{
              isResolved isOutdated path line
              comments(first:50){nodes{databaseId body author{login} diffHunk}}
            }
          }
        }
      }
    }'
  ```

- Loop with the `after:` cursor until `hasNextPage` is false. A thread reporting more than 50 comments → note the truncation in that comment record's `discussion`.
- Keep threads where `isResolved == false`.
- Skip threads whose most recent comment author is the PR author (already answered). List skipped threads in one line for awareness.
- Bot reviewer comments are processed like any other unless the user says otherwise.
- Per thread build one comment record: `id` = first comment's `databaseId`, `path`, `line`, `body` = first comment's body, `author`, `diffHunk`, `isOutdated`, `discussion` = remaining thread comments as `author: body` lines.
- Outdated threads are flagged (passed through with `isOutdated: true`), not dropped.
- Zero unresolved threads → report "no unresolved review comments" and stop.

</section>

<section id="dispatch-mode">

- Preferred — Workflow tool available:

  ```
  Workflow({
    scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/address-review.js",
    args: { pr, owner, repo, comments: [{ id, path, line, body, author, diffHunk, isOutdated, discussion }] },
  })
  ```

  - Surface the workflow's `log()` lines as progress
  - Feed the returned `results[]` into `tldr-gate`
  - Skip `inline-fallback` — the workflow owns dispatch

- Fallback — Workflow tool unavailable: run `inline-fallback` below

</section>

<section id="inline-fallback">

- Only when the Workflow tool is unavailable. Mirror the workflow stages with `Agent` calls; findings stay local.
- Stage 1 — verify (parallel, one agent per comment, single message): adversarially try to REFUTE the comment against the current code. Invalid if the issue doesn't exist, is already handled, rests on a wrong assumption, or is out of the PR's scope. Invalid → draft a pushback reply per `reply-tone`.
- Stage 2 — evaluate (parallel, valid comments only): decide best fix — reviewer's proposal as written, or a better alternative. Prefer the proposal unless the alternative clearly wins on correctness, simplicity, or consistency. Output plan + files touched as repo-relative paths, never absolute.
- Stage 3 — recheck (parallel, alternatives only): adversarially try to refute each alternative plan. Refuted → revert to the reviewer's proposal.
- Stage 4 — fix (parallel): group fixes whose file sets overlap (compare paths repo-relative) into one agent each; disjoint groups run in parallel in a single message. Agents edit the working tree, never commit or push, and return a one-line summary + reply per comment.
- Same agent-availability rule as team-review: zero suitable agents → stop and tell the user; never inline-impersonate.

</section>

<section id="tldr-gate">

- Output MUST be a TLDR, not a wall of text:
  - One header line: `N fixed, M pushback, K failed`
  - One table, one row per comment: `path:line | fixed/pushback/failed | files | reply text` — `files` = the row's changed files from `results[].files`, comma-separated
  - Nothing else. No per-comment prose, no plan dumps. Details on request only.
- User MAY ask to see any row's diff before confirming.
- Single confirmation covers commits, push, and posting replies — this is the hard stop.
- User MAY drop a row, edit a reply, or flip a pushback to a fix before confirming. Apply edits verbatim.
- `failed` rows get no reply; list them for manual follow-up.

</section>

<section id="apply-and-reply">

- Only after the gate.
- Commit: one commit per fix group (conventional format, repo scope rules). Stage only files from `fixed` rows — never `git add -A`. Never `--no-verify`.
- A `failed` row's files overlapping a `fixed` row's files in the same group → STOP before committing that group and surface the overlap to the user instead of pushing partial edits.
- Push to the PR head branch.
- Reply per comment, one call each. Reply bodies are always passed as `--arg` data, never interpolated into the command or JSON:

  ```bash
  payload=$(mktemp)
  jq -n --arg body "$REPLY" '{body:$body}' >"$payload"
  gh api --method POST "repos/$OWNER/$REPO/pulls/$PR/comments/$COMMENT_ID/replies" --input "$payload"
  rm -f "$payload"
  ```

  - `COMMENT_ID` = the thread root `databaseId`

- Do NOT resolve threads — the reviewer resolves.
- Monitor CI after push; surface failures.
- Report one line: commits pushed + replies posted counts.

</section>

<section id="reply-tone">

- 1 or 2 short sentences maximum.
- No dashes of any kind. No semicolons.
- No trivia, no thanks, no filler, no restating the comment.
- State the outcome only: what changed, or why no change is made.
- Examples:
  - "Fixed. The null check now runs before the lookup."
  - "Left as is. The value is validated upstream in `parse_config`."

</section>

<section id="boundaries">

- Only GitHub writes: the push and the comment replies in `apply-and-reply`, both gated by `tldr-gate`.
- MUST NOT post reviews, edit the PR body, change labels, or resolve threads.
- MUST NOT reply to a comment marked `failed`.
- Every changed line MUST trace to a verified comment's fix plan — no drive-by refactors.

</section>
