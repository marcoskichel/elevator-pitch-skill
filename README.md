# empire

Claude Code skills for the solo founder commanding a one-person empire.

You're the CEO. The skills are your staff — review your PRs, research approaches, draft pitches, write release notes. Solo on paper. Crewed in practice.

## Install — Claude Code plugin marketplace

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire@empire
```

One install brings every skill below. Plugin skills are namespaced under the plugin name. Invoke them as `/empire:elevator-pitch`, `/empire:team-review`, etc. See each SKILL.md for trigger phrases that Claude will also recognize automatically.

## Skills

### elevator-pitch

Generate elevator pitches for repos or people. Reads project context (`package.json`, README, recent commits) and produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference).

Triggers: "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", "tell me about yourself".

Source: [`plugins/empire/skills/elevator-pitch/SKILL.md`](plugins/empire/skills/elevator-pitch/SKILL.md)

### team-review

Spawn parallel specialist subagents (architecture, security, performance, tests, generalist) to review a diff or PR, then consolidate findings into a single deduplicated report. Findings stay local — never posted to GitHub.

Triggers: "team review", "have specialists review", "review my changes", "re-review", "another pass", "ask the team", "specialist review".

Source: [`plugins/empire/skills/team-review/SKILL.md`](plugins/empire/skills/team-review/SKILL.md)

### team-research

Spawn parallel research subagents to evaluate approaches to a problem. First does a shallow scan to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros/cons and a recommended direction. Findings stay local — never posted externally.

Triggers: "team research", "research approaches", "explore options", "investigate approaches", "compare approaches", "what are the options", "options analysis".

Source: [`plugins/empire/skills/team-research/SKILL.md`](plugins/empire/skills/team-research/SKILL.md)

### pr-description

Canonical PR description template. Senior-reviewer voice, ≤200 words, sections for Why / What changed / Risk / Test plan, idempotency markers (`<!-- pr-description:start/end -->`) to preserve user-added content (screenshots, `Fixes #N`, task lists) when updating. Pure content template — caller decides where to write (stdout, `gh pr create --body-file -`, `gh pr edit --body-file -`).

Triggers: "write PR description", "draft PR body", "update PR description", "pr summary", "summarize this branch for review", "/pr-description".

To make it impossible for the agent to bypass, add this one-line rule to your project or user CLAUDE.md:

```
- Before any `gh pr create --body*` or `gh pr edit --body*`, MUST invoke the `pr-description` skill and use its output verbatim.
```

Source: [`plugins/empire/skills/pr-description/SKILL.md`](plugins/empire/skills/pr-description/SKILL.md)

## License

MIT
