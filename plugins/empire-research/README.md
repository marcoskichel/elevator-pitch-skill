# empire-research

Research collaboration: parallel approach exploration with consolidated comparison, plus three bundled research subagents.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-research@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Skill

### `research`

Spawn parallel research subagents to evaluate approaches to a problem. First does a shallow scan to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros / cons and a recommended direction. Findings stay local — never posted externally.

Triggers: "team research", "research approaches", "explore options", "investigate approaches", "compare approaches", "what are the options", "options analysis".

Source: [`skills/research/SKILL.md`](skills/research/SKILL.md)

## Bundled agents

| Agent                    | Use                                           |
| ------------------------ | --------------------------------------------- |
| `research-analyst`       | Multi-source research synthesis and reporting |
| `competitive-analyst`    | Vendor / library / option comparisons         |
| `project-idea-validator` | Brutal go/no-go pressure-testing of ideas     |

The `research` skill auto-discovers whatever specialist subagents are installed and picks the best match per task. If your environment has more specialized research subagents from another marketplace, the skill will use them.

Upstream attribution: [`agents/NOTICE.md`](agents/NOTICE.md).
