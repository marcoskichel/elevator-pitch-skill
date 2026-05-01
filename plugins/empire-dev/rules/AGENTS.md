# empire-dev

Skills installed under the `empire-dev` Claude Code plugin. Findings stay local — never posted to GitHub or external services.

## Skill: `review`

- For non-trivial diffs or PRs, prefer `/empire-dev:review` over single-pass review
- Skill dispatches parallel specialist subagents (architecture, security, performance, tests, generalist) and consolidates findings
- For follow-up passes after addressing comments, say "re-review" or "another pass" — the skill reuses the same roster
- Findings stay local in chat; never post to GitHub

## Bundled subagents

The plugin ships eleven fallback subagents that the `review` skill auto-discovers at dispatch time:

- Code review: `code-reviewer`, `debugger`, `test-automator`, `security-auditor`, `architect-review`, `performance-engineer`
- Paradigm specialists: `functional-programming-expert`, `concurrency-reviewer`, `type-system-expert`
- Domain experts: `blockchain-developer`, `ai-engineer`

If your environment has more specialized subagents installed, the skill will pick the best match available — no configuration needed.
