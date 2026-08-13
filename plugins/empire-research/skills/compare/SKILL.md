---
name: compare
description: >
  Trigger when user says: "compare libs", "compare frameworks",
  "/empire-research:compare", "evaluate options", "side by side", "head to
  head", "X vs Y", "which is better", "tooling comparison", "weigh these
  options", "decide between these". Closed comparison of tools, libraries,
  frameworks, vendors, or architectural choices — NOT competitors (use
  `/empire-product:recon`). User has a known option set; produces a
  side-by-side matrix on user-defined dimensions and recommends a winner.
  Findings stay local — never posted externally.
compatibility: Requires network access (web search and fetch); dispatches research subagents. Runs in Claude Code and OpenAI Codex; a bundled persona fills the roster when no named subagents are installed.
---

<section id="purpose-vs-explore">

- Use `compare` when the user already has a known finite set of options to evaluate
- Use the `explore` skill instead when the solution space is open and options need to be enumerated first
- If user input describes a problem without specific options, suggest the `explore` skill and confirm before proceeding here

</section>

<section id="context-gathering">

- Read conversation for: option list, use case, constraints, decision criteria
- Required inputs before dispatch:
  - Concrete option names (at least 2; ideally 3–5)
  - Use case / what the chosen option must do well
  - Constraints (stack, scale, budget, license, team familiarity)
  - Decision dimensions (perf, DX, ecosystem, maturity, license, cost, etc.)
- If any required input is missing → ask one clarifying question at a time
- For decision dimensions, suggest a sensible default set if user has no preference (see `default-dimensions`)
- MUST confirm option list AND dimension list with user before dispatch
- MUST NOT proceed if option list has < 2 options — redirect to the `explore` skill

</section>

<section id="default-dimensions">

When the user does not specify dimensions, suggest the relevant subset of:

- Tech library / framework: performance, DX, ecosystem, maturity, type safety, bundle / runtime size, license, community size, breaking-change history
- Vendor / SaaS: pricing model, free tier, lock-in risk, data residency, SLA, support quality, integration coverage
- Architectural choice: complexity, operational cost, scaling profile, team skill match, reversibility, debuggability

User can add, remove, or reweight dimensions before dispatch.

</section>

<section id="dispatch-mode">

- After the option list and dimensions are confirmed, dispatch scoring one of two ways
- Preferred — a workflow runner is available; the same script runs on every runner, only the call shape differs:

  - Claude Code: `Workflow({ scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/compare-score.js", args })`
  - pi: the `pi-dynamic-workflows` extension registers a `workflow` tool — `workflow({ name: "compare-score", description, scriptPath: <this skill dir>/workflows/compare-score.js, args })`; `scriptPath` resolves against the session cwd, so pass the absolute path to the bundled copy. `workflow` appears in the session's native tool set, NOT via MCP; not visible this session → use the fallback
  - Any other host exposing a JS workflow runner with `agent()`/`parallel()`: same script, its own call shape
  - The script scores each option in isolation (blind to rivals) with structured per-dimension output
  - `args`: `{ useCase, constraints, dimensions: [{ name, description }], options: [{ name, description }] }`

  - Surface the workflow's `log()` lines as progress
  - Feed the returned `options[]` into `consolidated-matrix`; apply dimension weights in the skill so the user can reweight without re-running
  - Skip `agent-selection` and `parallel-dispatch` — the workflow owns dispatch

- Fallback — no workflow runner (e.g. OpenAI Codex): use `agent-selection` then `parallel-dispatch` below

</section>

<section id="agent-selection">

- Fallback path — only when no workflow runner is available (see `dispatch-mode`)
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

<section id="consolidated-matrix">

- After all option-agents return, produce side-by-side matrix
- If the workflow returns `stats.scored < stats.requested`, MUST name the options that failed and ask whether to re-run them before showing the matrix
- Required output structure:

  ```
  ## Comparison Matrix

  | Dimension     | Option A | Option B | Option C |
  |---------------|----------|----------|----------|
  | <dimension 1> | 4 — note | 3 — note | 5 — note |
  ...
  | TOTAL         | 22       | 19       | 27       |
  ```

- Apply user-supplied weights to dimensions if provided; otherwise unweighted sum
- Highlight cells where one option dominates or underperforms by a clear margin
- `## Conflicts` section — where agents cite contradicting evidence; state each side
- `## Recommendation` — winner + rationale + when the runner-up would be the better pick (decision criteria)
- `## Caveats` — known unknowns, sources of uncertainty, freshness of data
- MUST cite sources from agent reports
- MUST present report then stop; ask user whether to proceed with chosen option

</section>

<section id="confidence-tagging">

- Mark each cell or claim as `[Confirmed]`, `[Estimated]`, or `[Inferred]`:
  - Confirmed: cited official docs, benchmarks, source code
  - Estimated: derived from indirect evidence (community reports, third-party benchmarks)
  - Inferred: agent's reasoning, no direct citation
- MUST never present `[Inferred]` data as confirmed fact

</section>

<section id="guardrails">

- MUST gather option list AND dimension list before any dispatch
- MUST confirm both with user before dispatch
- MUST dispatch scoring via the `compare-score` workflow when a workflow runner is available; else dispatch in parallel (single message, multiple tool uses), one agent per option
- MUST keep findings local in chat only
- MUST NOT post to Slack, GitHub, Jira, or any external system unless user explicitly authorizes
- MUST NOT pick a winner without showing the matrix
- MUST NOT begin implementation
- MUST mark inferred data as such — never present speculation as fact
- The bundled persona in `references/personas/` always provides a fallback evaluator — a missing named subagent is never a reason to stop; if the platform cannot spawn subagents at all → MUST stop and tell user; never inline-impersonate an evaluator in the main thread

</section>
