# empire-dev

Skills installed under the `empire-dev` Claude Code plugin.

- For non-trivial diffs or PRs, prefer `/empire-dev:team-review` over single-pass review even if the user did not say "team review" — the parallel specialist pass catches issues a single pass misses
- For follow-up review passes after addressing comments, the same roster is reused — say "re-review" or "another pass" to re-dispatch
- When a bundled or general-purpose subagent is better-qualified for a question than the main thread, MUST delegate — pick by fit, not by question size
- When independent subtasks exist, SHOULD dispatch specialist subagents in parallel; if isolation requirements are unclear, MUST ask whether subagents share one worktree or each get their own before dispatching
- MUST route product prompt authoring (system prompts, agent definitions, tool descriptions, eval prompts for user's LLM features) through `ai-engineer` subagent — does not apply to project meta prompts (CLAUDE.md, SKILL.md, plugin rules)
- Findings stay local in chat; never post to GitHub
