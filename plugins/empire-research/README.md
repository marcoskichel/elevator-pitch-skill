# empire-research

Research collaboration: open-ended exploration plus closed comparison, with consolidated reports. Two skills, one bundled subagent.

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

## Skills

### `explore`

Open-ended approach exploration. Used when the solution space is open: user knows the problem, not the options. Workflow: confirm problem → shallow scan to enumerate 3–5 candidate approaches → user picks subset → parallel deep dive per approach → consolidated report with recommendation. Findings stay local — never posted externally.

Triggers: "explore options", "what could we do for X", "research approaches", "investigate approaches", "what are the options", "options analysis".

Source: [`skills/explore/SKILL.md`](skills/explore/SKILL.md)

### `compare`

Closed comparison of a known set of options head-to-head. Used when user already has options A, B, C and wants a side-by-side matrix. Workflow: confirm option list + dimensions → parallel scoring per option → consolidated weighted matrix → recommendation with caveats. Confidence-tagged data. Findings stay local.

Triggers: "compare libs", "compare frameworks", "evaluate options", "side by side", "head to head", "X vs Y", "which is better", "tooling comparison", "decide between these".

Source: [`skills/compare/SKILL.md`](skills/compare/SKILL.md)

## Bundled agents

| Agent              | Use                                                   |
| ------------------ | ----------------------------------------------------- |
| `research-analyst` | Multi-source research synthesis, broad info retrieval |

Both skills auto-discover whatever specialist subagents are installed and pick the best match per task. If your environment has more specialized subagents from another marketplace, the skills will use them.

Upstream attribution: [`agents/NOTICE.md`](agents/NOTICE.md).
