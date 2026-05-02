---
name: pr-description
description: >
  Render the canonical PR description body. Use whenever drafting, writing,
  updating, refreshing, or regenerating a "PR description", "PR body", "pull
  request description", "pull request body", "PR summary", "PR template",
  "GitHub PR body", or any text destined for `gh pr create --body`, `gh pr
  create --body-file`, `gh pr edit --body`, `gh pr edit --body-file`, or a
  GitHub PR template. Triggers on phrases like "draft a PR", "write the PR",
  "summarize this branch for review", "regenerate PR body". MUST be invoked
  before any `gh pr create --body*` or `gh pr edit --body*` per the empire-git
  rules. Output is markdown ready to pipe to stdin.
allowed-tools: Bash Read Glob Grep
---

# PR Description Template

IMPORTANT: Output the rendered description verbatim. Do not summarize, paraphrase, or describe this skill. The caller pipes your output to `gh pr create` or `gh pr edit` unchanged.

## Voice

- Senior reviewer. Direct. Active voice. Imperative mood.
- No "this PR", "this commit", "I am", "we", filler openers.
- Explain intent, not mechanics. Cut anything visible in the diff.
- No emoji. No H1. No marketing tone. No "N/A" or "Risk: None".

## Length

| Diff size | Budget                                                    |
| --------- | --------------------------------------------------------- |
| ≤ 100 LOC | ≤ 80 words, drop Risk/Test plan if trivial                |
| ≤ 500 LOC | ≤ 200 words, full sections                                |
| > 500 LOC | ≤ 200 words, flag size in Risk, summarize at higher level |

Skip empty sections entirely.

## Sections

Render between markers. Preserve everything outside markers when updating.

```
<!-- pr-description:start -->
## Why
1–2 sentences. Problem or goal. Link issue if a commit references one.

## What changed
3–6 bullets. Behavioral changes only. File paths only when non-obvious.

## Risk
Migrations, breaking API, new env vars or deps, rollback notes, perf concerns. Omit section if trivial. Prefix breaking changes with `BREAKING:`.

## Test plan
Reproducible local steps. Skip CI-covered checks (lint, typecheck, unit).
<!-- pr-description:end -->
```

## Update mode

If an existing body is provided:

- Replace only content between `<!-- pr-description:start -->` and `<!-- pr-description:end -->`.
- Preserve all content outside markers (screenshots, reviewer notes, `Fixes #N`, task lists).
- If markers are absent: wrap new body in markers, append after author-written content (images, issue refs, custom H2s).

## Special cases

- Formatting/whitespace only: single line `Formatting only. No behavior change.` between markers.
- Title (when requested): Conventional Commits, lowercase, no period, ≤ 72 chars.
- Body language matches the language of recent commit messages.

## Anti-patterns

| Bad                         | Good                                                          |
| --------------------------- | ------------------------------------------------------------- |
| "This PR adds support for…" | "Add support for…"                                            |
| "We refactor auth to…"      | "Refactor auth: extract token validation into…"               |
| "Various fixes"             | (list each)                                                   |
| "Fixes bug"                 | "Fix off-by-one in pagination cursor when total % limit == 0" |
| "Updated tests"             | (omit — visible in diff)                                      |
| "Renamed X to Y"            | (omit unless rollout-relevant)                                |
