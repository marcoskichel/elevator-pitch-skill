---
name: pr-comment-reply
description: >
  Render the canonical reply text for a PR review comment. Use when drafting,
  writing, or posting a "PR comment reply", "review comment reply", "reply to
  this comment", "respond to this review comment", "answer the reviewer",
  "reply on the PR thread", or any text bound for `gh api` review-thread
  replies, `gh pr comment`, or a GitHub review comment box. Triggers on "reply
  to the comment", "answer this review comment", "respond to the reviewer",
  "draft a reply", "post a reply on the PR". Outputs plain text for the caller
  to post unchanged.
compatibility: Requires nothing beyond the calling agent. Runs in Claude Code and OpenAI Codex.
---

# PR Comment Reply Template

IMPORTANT: Output the rendered reply verbatim. Do not summarize, paraphrase, or describe this skill. The caller posts your output to GitHub unchanged.

CRITICAL:

- 1 or 2 short sentences. Never more.
- State the outcome only: what changed, or why nothing changed, or the answer to the question.
- No trivia. No thanks. No filler. No restating the comment.

## Voice

- Sounds like a human teammate typing a quick reply. Plain words. Direct.
- No dashes of any kind as connectors: no em dash, no en dash, no spaced hyphen. Hyphenated words like `off-by-one` stay fine.
- No semicolons. Split into two sentences instead.
- No technical jargon beyond what the comment itself uses. Prefer "runs before" over "precedes", "removed" over "deprecated", "check" over "validation logic". Code identifiers in backticks are fine.
- No "great catch", "good point", "thanks for flagging", "you're right that".
- No hedging: no "I think", "probably", "should be fine".
- No emoji. No sign-offs.

## Reply types

| Situation                 | Reply shape                                 |
| ------------------------- | ------------------------------------------- |
| Fixed the issue           | What the fix does now. Not how it was done. |
| Not changing              | "Left as is." plus the one reason.          |
| Answering a question      | The answer. Nothing else.                   |
| Deferring to a follow-up  | What is deferred and where it is tracked.   |
| Comment is wrong or stale | The fact that disproves it, stated plainly. |

## Examples

- "Fixed. The null check now runs before the lookup."
- "Left as is. The value is checked upstream in `parse_config`."
- "Yes, the retry covers timeouts too."
- "Moved to a follow-up, tracked in #142."
- "That path was removed in the last push. The guard lives in `resolve_user` now."

## Anti-patterns

| Bad                                                        | Good                                              |
| ---------------------------------------------------------- | ------------------------------------------------- |
| "Great catch! Fixed in the latest commit."                 | "Fixed. The cursor resets when the list empties." |
| "You're right that this could fail; updated the logic."    | "Fixed. Empty input now returns early."           |
| "This is intentional — the cache invalidates upstream."    | "Left as is. The cache clears upstream on write." |
| "Refactored to leverage the existing validation paradigm." | "Reused the existing check in `validate_input`."  |
| "Hmm, I think this should be fine as is."                  | "Left as is. The lock already covers this path."  |
| "Done."                                                    | "Fixed. The timeout now applies per request."     |

## Special cases

- Multiple comments in one pass: render one reply per comment, each standalone. Never reference another thread.
- Reply language matches the language of the comment being answered.
- Never resolve the thread, edit the PR body, or post a review. The reply text is the only output.
