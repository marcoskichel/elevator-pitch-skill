---
name: pr-review-post
description: >
  Post a GitHub PR review (verdict + inline comments) in one API call. Use
  when posting, submitting, or publishing a "PR review", "code review",
  "review with inline comments", "approve the PR", "request changes", or any
  payload bound for `gh api repos/*/pulls/*/reviews`. Triggers on "post the
  review", "submit the review", "publish the review comments", "approve this
  PR", "request changes on the PR", "leave a review". MUST be used for any
  review POST so comments and verdict land atomically. Never posts without
  the caller's confirmed verdict.
compatibility: Requires the gh CLI and network access. Runs in Claude Code and OpenAI Codex.
allowed-tools: Bash Read Grep
---

# PR Review Post

Posts ONE review — verdict, summary, and inline comments — in a single GitHub API call. The caller supplies the confirmed event, summary, and comment list; this skill owns the mechanics of anchoring, payload building, posting, and retrying.

CRITICAL:

- The ENTIRE review goes in ONE POST. Never post comments individually; never create a pending review then submit separately.
- Never post without an explicit confirmed verdict from the caller. This skill does not decide the verdict.

## Step 1 — Resolve the target

- Inputs from the caller: PR (number or URL), event (`APPROVE` | `REQUEST_CHANGES` | `COMMENT`), summary body (may be empty), and the comment list (`path`, `line`, optional `start_line`, `side`, `body`).
- Derive `OWNER`/`REPO` from the PR's OWN base repo, never from `gh repo view` (cwd may be a different repo or fork): `gh pr view "$PR" --json number,url` then parse `OWNER`/`REPO` from `.url` and set `PR` from `.number`.
- Fetch the head SHA right before posting: `SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)`. If the caller validated comments against an earlier SHA and it changed, warn that anchors may have drifted and get re-confirmation before posting.

## Step 2 — Anchor comments

- Every inline comment MUST land on a line present in the PR diff:
  - Added or context line → `side: RIGHT`
  - Deleted line → `side: LEFT`, only when that line sits inside a displayed diff hunk
  - Span → `start_line` + `line` (same side)
- A finding outside the diff → fold into the summary body. Never invent a line.

## Step 3 — Build the payload

Build with `jq` into a temp file; pass every comment `body` and the summary as `--arg` values, NEVER via string interpolation (bodies hold quotes, backticks, `$()`):

```bash
payload=$(mktemp)
# Append each comment as data, never interpolated into the JSON:
comments='[]'
comments=$(jq -c --arg path "$P" --argjson line "$N" --arg side RIGHT --arg body "$Q" \
  '. + [{path: $path, line: $line, side: $side, body: $body}]' <<<"$comments")
# repeat per comment; for a span add --argjson start_line and --arg start_side
jq -n --arg commit "$SHA" --arg event "$EVENT" --arg body "$SUMMARY" --argjson comments "$comments" \
  '{commit_id: $commit, event: $event, body: $body, comments: $comments}' >"$payload"
```

Payload shape:

```json
{
  "commit_id": "<SHA>",
  "event": "COMMENT|APPROVE|REQUEST_CHANGES",
  "body": "<summary or empty>",
  "comments": [
    { "path": "src/x.ts", "line": 42, "side": "RIGHT", "body": "..." },
    {
      "path": "src/x.ts",
      "start_line": 40,
      "start_side": "RIGHT",
      "line": 44,
      "side": "RIGHT",
      "body": "..."
    }
  ]
}
```

- With `comments` present, any event MAY omit `body`; with no `comments`, `COMMENT` and `REQUEST_CHANGES` require a non-empty `body` (`APPROVE` MAY always be empty).

## Step 4 — Post

```bash
gh api --method POST "repos/$OWNER/$REPO/pulls/$PR/reviews" --input "$payload"
rm -f "$payload"
```

- After posting, report the review URL from the API response.
- On API error (line not in diff, stale `SHA`): re-resolve the anchor or `SHA` and retry the single call, max 2 retries. If a retry changes an anchor the caller already validated, re-confirm that comment first. Never split into multiple posts; surface to the caller after repeated failure.

## Boundaries

- The single review POST is the only GitHub write. MUST NOT push commits, edit the PR body, change labels, or comment outside the review.
- MUST NOT modify the code under review.
- MUST NOT alter comment bodies, the summary, or the event beyond what the caller confirmed.
