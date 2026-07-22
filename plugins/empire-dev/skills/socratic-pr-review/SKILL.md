---
name: socratic-pr-review
description: >
  Trigger when user says: "socratic review", "socratic pr review", "socratic
  code review", "review this PR socratically", "review the PR with questions",
  "ask questions on the PR", "question-style review", "leave socratic comments",
  "/empire-dev:socratic-pr-review". First explains in plain words what the PR
  does and sanity-checks its direction, then runs team-review, turns findings
  into short question-style inline comments, walks each past the user with a
  quick note on the code it touches, and posts ONE review (approve / request
  changes / comment) at the end. Posts to GitHub only after the user confirms
  the comments and the final verdict.
compatibility: Requires the gh CLI and network access; dispatches review subagents.
allowed-tools: Bash Read Glob Grep Skill Agent WebSearch WebFetch
---

<section id="overview">

Socratic PR review: lead the author to the issue with a question; don't dictate the fix.
Talk like a teammate — short phrases, plain words, no jargon. The point is to make the review easy to follow and easy to weigh in on.
Pipeline: resolve PR → say what it does → check the direction → team-review → draft questions → re-check vs code → walk them one by one → post one review.
Confirm sparingly. Skip the obvious. The one hard stop is the single GitHub post.
This is the only empire-dev skill that writes to GitHub. It posts exactly ONE review, and only after the user OKs the comments and the verdict.

</section>

<section id="target-detection">

- Resolve the target PR first.
- Signals, in order:
  - Explicit PR number or URL in the invocation
  - Open PR for the current branch: `gh pr view --json number,url,headRefOid`
  - PR referenced earlier in the conversation
- Derive `OWNER`/`REPO` from the PR's OWN base repo, never from `gh repo view` (cwd may be a different repo or fork):
  - `gh pr view "$PR" --json number,url,baseRefName,headRefOid` (a bare number resolves against cwd; pass a full URL for any other repo or fork)
  - Parse `OWNER`/`REPO` from the returned `.url` (`https://github.com/OWNER/REPO/pull/N`); set `PR` from `.number`
- State the target in one line: `OWNER/REPO#PR @ <sha>` + url, then keep going.
- Confirm ONLY when it's genuinely unclear — no explicit target and either zero or several candidate PRs. A clear target needs no confirmation.
- Treat `SHA` as provisional; re-fetch it right before posting (see [post-review](#post-review)).

</section>

<section id="understand">

Runs BEFORE any review. Goal: know what the PR does, so every later question lands in context.

- Dispatch parallel read-only subagents (Claude Code: `Explore` or `general-purpose` in one message; other agents: spawn concurrently), findings in chat only:
  - Reader — read the PR description + full diff → the change and the author's intent
  - Integrator — trace how it wires into existing code → what calls it, what it replaces, where the data flows
- From their results, tell the user in plain words:
  - What it does — 1-3 short sentences, everyday language, the kind you'd say out loud
  - Touches — the key files or areas
  - Fits in by — one line on how it hooks into what's already there
- Informational. Present it, then continue — no gate here.

</section>

<section id="check-direction">

Right after "what it does", give a quick read on the approach — still plain words.

- Direction — is this a sound way to solve it? one line
- Tradeoffs — the real ones, as short phrases (e.g. "quick to ship, adds a dependency")
- Alternative — propose one ONLY if its tradeoffs are clearly better; otherwise say the direction looks fine and move on
- Keep it to a few lines. A gut-check on direction, not a design doc.
- If a better alternative exists, pause so the user can pick the direction before you spend the review on this one. Otherwise continue.

</section>

<section id="run-team-review">

- Invoke the `team-review` skill on the resolved PR; pass the PR number.
- Let team-review pick the roster and return its consolidated tiered report.
- Use the report's Recommended actions as the comment seed set.
- team-review never posts; this skill owns all GitHub writes.

</section>

<section id="draft-comments">

- Convert each Recommended action into one draft inline comment.
- Anchor every comment to `path` + `line` from the diff:
  - Added or context line → `side: RIGHT`
  - Deleted line → `side: LEFT`, only when that line sits inside a displayed diff hunk; else fold into the summary body
  - Span → `start_line` + `line` (same side)
- Inline comments MUST land on lines present in the PR diff. Finding outside the diff → fold into the summary body, never invent a line.
- Drop Single-source low-confidence findings unless the lone specialist owns that category (per team-review tiering). Do not auto-include nits.
- Draft only; nothing is posted in this section.

</section>

<section id="socratic-style">

- Phrase each comment as the question a curious teammate would ask reading the diff.
- Lead with genuine curiosity, not a gotcha. Seek to understand the change, not corner the author.
- Sound natural and conversational. Plain words, thinking out loud. Drop stiff phrasing like "Is `X` guaranteed to be non-null".
- When there's a clear set of answers, name them in the question: "Do `permissions` / `harness-support` replace `allowed-tools` / `compatibility`, or coexist?"
- Two shapes, both valid:
  - Understand intent: "What are the `permissions` values?", "Why drop the retry here?"
  - Surface a gap: "What happens when `items` is empty?" not "This crashes on empty input."
- Assume competence; no rhetorical or leading-to-humiliate questions.
- One question per comment. No stacked questions.
- Example transforms:
  - "Missing null check on `user`" → "Is `user` ever null by the time we reach this?"
  - "This N+1 query is slow" → "How many queries does this loop fire per request?"

</section>

<section id="recheck">

- Re-verify EVERY draft comment against the current code in one batch pass, BEFORE you walk the comments one by one.
- Read the actual file and line; confirm the issue still exists in the diff as drafted.
- MAY use WebSearch / WebFetch to confirm API behavior, version semantics, or library contracts the finding depends on.
- Drop the comment if re-check shows it is wrong, already handled, or off-target. State dropped ones briefly.
- Correct the anchor line if the finding is real but the line drifted.

</section>

<section id="comment-rules">

- Length: short and direct, ideally under 150 characters.
- No fix suggestions UNLESS the fix is unambiguous; only then MAY append a GitHub ```suggestion block.
- Comment prose: no dashes, no emojis.
- One issue per comment.
- Use backticks for identifiers, paths, and symbols.

</section>

<section id="walk-comments">

- Show comments ONE AT A TIME. Never dump the full list — one question is easy to weigh in on; ten at once isn't.
- For each, in plain words:
  - Context — what this bit of code does + what the change did to it, 1-2 short lines, so the user can weigh in with authority
  - `path:line` + a 1-2 line diff snippet
  - The draft question
  - Why it matters — one short line (tier + category from team-review)
- Then: keep as-is, reword, or drop.
- Wait for the user's call on the current comment before showing the next.
- Track the kept comments; apply any edits verbatim.

</section>

<section id="verdict">

- Once the comments are settled, propose the review in ONE message:
  - Event — `APPROVE` (no unresolved must-fix), `REQUEST_CHANGES` (≥1 unresolved must-fix), or `COMMENT` (questions worth raising, no blocking stance)
  - Summary — short, MAY be empty; same prose rules (no dashes, no emojis)
  - Destination — `OWNER/REPO#PR @ <sha>`
- One confirmation covers all three. Get an explicit "post" before writing to GitHub — this is the hard stop.
- `REQUEST_CHANGES` blocks the PR; call that out in the same message.
- User MAY switch the event or edit the summary before confirming.

</section>

<section id="post-review">

- Post the ENTIRE review in ONE GitHub API call. Never post comments individually; never create a pending review then submit separately.
- Right before posting, re-fetch `SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)`. If it changed since [target-detection](#target-detection), warn the user (anchors may have drifted) and re-confirm; otherwise the [verdict](#verdict) OK stands.
- Build the payload with `jq` into a temp file; pass every comment `body` and the summary as `--arg` values, NEVER via string interpolation (bodies hold quotes, backticks, `$()`). Then a single POST, deleting the temp file after:

  ```bash
  payload=$(mktemp)
  # Append each comment as data, never interpolated into the JSON:
  comments='[]'
  comments=$(jq -c --arg path "$P" --argjson line "$N" --arg side RIGHT --arg body "$Q" \
    '. + [{path: $path, line: $line, side: $side, body: $body}]' <<<"$comments")
  # repeat per comment; for a span add --argjson start_line and --arg start_side
  jq -n --arg commit "$SHA" --arg event "$EVENT" --arg body "$SUMMARY" --argjson comments "$comments" \
    '{commit_id: $commit, event: $event, body: $body, comments: $comments}' >"$payload"
  gh api --method POST "repos/$OWNER/$REPO/pulls/$PR/reviews" --input "$payload"
  rm -f "$payload"
  ```

- `payload.json` shape:

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
- After posting, report the review URL from the API response.
- On API error (line not in diff, stale `SHA`): re-resolve the anchor or `SHA` and retry the single call, max 2 retries. If a retry changes an anchor the user validated, re-confirm that comment first. Never split into multiple posts; surface to the user after repeated failure.

</section>

<section id="boundaries">

- The only GitHub write is the single review POST in [post-review](#post-review), gated by [verdict](#verdict) approval.
- MUST NOT push commits, edit the PR body, change labels, or comment outside the review.
- MUST NOT modify the code under review.

</section>
