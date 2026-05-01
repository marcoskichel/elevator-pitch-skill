## Empire team collaboration

Skills installed under the `empire-team` Claude Code plugin. Findings stay local — never posted to GitHub or external services.

### Code review

- For non-trivial diffs or PRs, prefer `/empire-team:review` over single-pass review
- The skill spawns parallel specialist subagents (architecture, security, performance, tests, generalist) and consolidates a deduplicated report
- Use plain inline review only for trivial diffs (typos, single-line fixes, formatting)

### Research

- For approach exploration, use `/empire-team:research` instead of ad-hoc one-pass investigation
- Two-step flow: shallow scan enumerates 3–5 candidate approaches; user picks; one research subagent per pick consolidates pros / cons / recommendation
- Use this skill when the user asks "what are the options", "compare approaches", "research X", or before committing to a non-trivial design choice

Conventions:

- Subagents run in parallel — dispatch all in one tool batch, never sequentially
- Final report aggregates findings; do not surface individual subagent transcripts unless asked
