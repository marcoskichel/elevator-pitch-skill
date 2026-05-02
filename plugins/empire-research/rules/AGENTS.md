# empire-research

Skills installed under the `empire-research` Claude Code plugin. Findings stay local — never posted to Slack, GitHub, Jira, or external systems.

## Skill: `explore`

- For open-ended approach exploration ("what could we do for X?"), use `/empire-research:explore` instead of ad-hoc one-pass investigation
- Skill performs a shallow scan first to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros / cons and a recommended direction
- Skill never implements — recommendation only. Wait for user to choose the direction before any edits.

## Skill: `compare`

- For closed comparison of a known set of options head-to-head ("A vs B vs C"), use `/empire-research:compare`
- Skill skips the shallow scan because options are already known; dispatches one agent per option in parallel; consolidates a side-by-side matrix with confidence-tagged scoring
- Output marks each cell as `[Confirmed]`, `[Estimated]`, or `[Inferred]` so users know what's evidence vs. reasoning

## Bundled subagent

The plugin ships one fallback subagent that both skills auto-discover at dispatch time:

- `research-analyst` — multi-source research synthesis and reporting

If your environment has more specialized research subagents installed (e.g. competitive-analyst, market-researcher, language-specific experts), the skills will pick the best match available — no configuration needed.
