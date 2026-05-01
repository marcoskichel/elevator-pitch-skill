# empire-team

Parallel agentic collaboration: dispatch specialist subagents to review code or research approaches, then consolidate findings.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-team@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Skills

### `review`

Spawn parallel specialist subagents (architecture, security, performance, tests, generalist) to review a diff or PR, then consolidate findings into a single deduplicated report. Findings stay local — never posted to GitHub.

Triggers: "team review", "have specialists review", "review my changes", "re-review", "another pass", "ask the team", "specialist review".

Source: [`skills/review/SKILL.md`](skills/review/SKILL.md)

### `research`

Spawn parallel research subagents to evaluate approaches to a problem. First does a shallow scan to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros/cons and a recommended direction. Findings stay local — never posted externally.

Triggers: "team research", "research approaches", "explore options", "investigate approaches", "compare approaches", "what are the options", "options analysis".

Source: [`skills/research/SKILL.md`](skills/research/SKILL.md)

## Companion plugin

The `review` and `research` skills auto-discover whatever specialist subagents are installed. For a ready-made roster of fallback agents (code review, paradigm specialists, domain experts, research roles), install [`empire-agents`](../empire-agents/README.md):

```sh
/plugin install empire-agents@empire
```

The full `empire@empire` bundle includes both plugins. If you already have specialized subagents from another marketplace, the skills will pick the best match available — no extra configuration required.
