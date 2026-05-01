# empire-research

Skills installed under the `empire-research` Claude Code plugin. Findings stay local — never posted to Slack, GitHub, Jira, or external systems.

## Skill: `research`

- For approach exploration, use `/empire-research:research` instead of ad-hoc one-pass investigation
- Skill performs a shallow scan first to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros / cons and a recommended direction
- Skill never implements — recommendation only. Wait for user to choose the direction before any edits.

## Bundled subagents

The plugin ships three fallback subagents that the `research` skill auto-discovers at dispatch time:

- `research-analyst` — multi-source research synthesis and reporting
- `competitive-analyst` — vendor / library / option comparisons
- `project-idea-validator` — brutal go/no-go pressure-testing of ideas

If your environment has more specialized research subagents installed, the skill will pick the best match available — no configuration needed.
