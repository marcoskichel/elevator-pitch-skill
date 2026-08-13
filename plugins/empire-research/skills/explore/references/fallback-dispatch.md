# Inline fallback dispatch

Use ONLY when no JS workflow runner is available (see `dispatch-mode` in SKILL.md).

<section id="agent-selection">

- Pick one deep agent per selected approach
- Agent names vary by environment; never assume a specific named agent exists — the bundled persona guarantees the roster can always be filled
- Source each deep researcher two ways; prefer the first, always have the second:
  - Named subagent — if the platform exposes research subagents, inspect what is available (Claude Code: the `Agent` tool's `subagent_type`; other agents: their own spawn mechanism)
  - Bundled persona — brief a general-purpose subagent with `references/personas/research-analyst.md`; use when no named subagent fits or the platform has no subagent registry
- For each selected approach, identify its dominant signal from these categories:
  - General synthesis, multi-source aggregation
  - Fast targeted retrieval, known-solution space
  - Quantitative datasets, benchmarks, numerical evidence
  - Peer-reviewed or scientific evidence
  - Emerging-tech trajectory, trend analysis
- For each signal that applies, pick the available agent whose name/description best matches; if multiple candidates fit, prefer the most specific; if none fit, use the most general research-synthesis agent available
- MUST always include at least one general research-synthesis agent to anchor the roster
- List chosen researcher per approach (named `subagent_type` or persona filename) + one-line rationale BEFORE dispatch
- If confident in every pick → dispatch immediately
- If uncertain about any pick → confirm roster with user before dispatch; allow swaps

</section>

<section id="parallel-deep-dispatch">

- Dispatch all researchers in parallel, one subagent per approach (Claude Code: one message with multiple `Agent` tool calls; other agents: spawn them concurrently)
- Each agent receives:
  - Original confirmed problem statement
  - The specific approach assigned to them
  - All known constraints and success criteria
  - Output format instruction (see below)
  - "Do NOT post findings to any external system. Report in chat only."
- Required deep agent output format:

  ```
  Approach: <name>

  Summary: <2-3 sentences>

  Pros:
  - <point>

  Cons:
  - <point>

  Key Evidence / Citations:
  - <source or concrete reference>

  Fit Rating: <High / Medium / Low> — <one sentence rationale>
  ```

- Cap each agent response under 500 words

</section>
