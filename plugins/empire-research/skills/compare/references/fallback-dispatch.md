# Inline fallback dispatch

Use ONLY when no JS workflow runner is available (see `dispatch-mode` in SKILL.md).

<section id="agent-selection">

- One agent per option for parallel deep evaluation
- Agent names vary by environment; never assume a specific named agent exists — the bundled persona guarantees the roster can always be filled
- Two ways to source each evaluator; prefer the first, always have the second:
  - Named subagent — if the platform exposes research subagents, inspect what is available (Claude Code: the `Agent` tool's `subagent_type`; other agents: their own spawn mechanism)
  - Bundled persona — brief a general-purpose subagent with `references/personas/research-analyst.md`; use when no named subagent fits or the platform has no subagent registry
- For each option, identify its dominant signal:
  - Library / framework / language → pick the most specific language or framework expert available; fall back to a general code or research agent
  - Vendor / SaaS / commercial product → pick a comparative-analysis or research-synthesis agent
  - Architectural choice → pick an architecture-review or systems-design agent
- MUST include at least one general research-synthesis agent in the roster to anchor cross-option consistency
- List chosen evaluator per option (named `subagent_type` or persona filename) + one-line rationale BEFORE dispatch
- If confident in every pick → dispatch immediately
- If uncertain about any pick → confirm roster with user before dispatch; allow swaps
- Skip the shallow-scan phase — options are already known

</section>

<section id="parallel-dispatch">

- Dispatch all evaluators in parallel, one subagent per option (Claude Code: one message with multiple `Agent` tool calls; other agents: spawn them concurrently)
- Each agent receives:
  - The specific option assigned to them (one option per agent)
  - The agreed-upon dimension list with descriptions
  - User constraints and use case
  - Output format instruction (see below)
  - "Score the assigned option ONLY against each dimension. Do not compare to other options. Do NOT post findings externally."
- Required per-option output format:

  ```
  Option: <name>

  Summary: <2-3 sentences>

  Per-dimension scoring:
  | Dimension | Score (1-5) | Evidence | Notes |
  |---|---|---|---|

  Pros:
  - <point>

  Cons:
  - <point>

  Key citations:
  - <source>
  ```

- Cap each agent response under 400 words
- Isolation rationale: each agent scores its option blind to rivals — independent, evidence-based scores with no anchoring bias; head-to-head comparison happens only in consolidation

</section>
