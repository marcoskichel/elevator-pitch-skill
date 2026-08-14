---
name: explore
description: >
  Trigger when user says: "explore options", "what could we do for X",
  "research approaches", "/empire-research:explore",
  "investigate approaches", "spawn research team", "what are the options",
  "options analysis", "explore solutions", "have the team explore". Open-ended
  exploration: shallow scan enumerates 3–5 candidate approaches, user picks
  subset to deep-dive, parallel research per approach, consolidated comparison
  with recommended direction. Findings stay local — never posted externally.
compatibility: Requires network access (web search and fetch); dispatches research subagents. Runs in Claude Code and OpenAI Codex; a bundled persona fills the roster when no named subagents are installed.
---

<section id="purpose-vs-compare">

- Use `explore` when the solution space is open: user knows the problem, not the options
- Use the `compare` skill instead when user already has a known set of options to evaluate head-to-head
- If user input names specific options (A vs B vs C), suggest the `compare` skill and confirm before proceeding here

</section>

<section id="context-gathering">

- Read conversation for problem statement, scope, constraints, success criteria
- Signals to read:
  - Explicit user description of the problem
  - Recent code or files providing technical context
  - Stated constraints (budget, timeline, stack, team size)
  - Prior approaches already ruled out
  - Definition of "good enough" outcome
- If problem statement unclear → ask one clarifying question at a time
- If structured choices help → use `AskUserQuestion` with concrete options
- MUST state inferred problem statement back to user before any dispatch
- MUST get user confirmation on problem statement
- MUST NOT dispatch any agent until problem is confirmed

</section>

<section id="shallow-scan">

- After problem confirmed, dispatch ONE research agent for broad enumeration
- Agent names vary by environment; never assume a specific named agent exists — the bundled persona guarantees the scan can always run
- Two ways to source the scanning agent; prefer the first, always have the second:
  - Named subagent — if the platform exposes a research subagent, pick the best match for general research synthesis or broad information retrieval (Claude Code: the `Agent` tool's `subagent_type`; other agents: their own spawn mechanism)
  - Bundled persona — brief a general-purpose subagent with `references/personas/research-analyst.md`; use when no named subagent fits or the platform has no subagent registry
- Shallow agent instructions:

  - Enumerate 3–5 candidate approaches only
  - One short paragraph per approach — no deep evaluation
  - Required output format:

    ```
    1. <Approach Name>
       <One-paragraph description — what it is, how it addresses the problem>

    2. <Approach Name>
       ...
    ```

  - Cap response under 300 words

- Present shallow-scan output to user verbatim before proceeding

</section>

<section id="user-gate">

- Gate exists because deep-dive spawns one parallel agent per approach (real cost) — user steers spend toward the approaches worth researching
- After shallow scan, present results and ask user:
  - Which approaches to deep-dive (may pick multiple)
  - Whether to add, remove, or reframe any approach
- MUST wait for explicit user selection before deep dispatch
- MUST NOT infer selection and proceed silently
- If user requests a different approach not in list → add it, confirm updated list

</section>

<section id="dispatch-mode">

- After approaches selected, dispatch the deep research one of two ways
- Preferred — a workflow runner is available; the same script runs on every runner, only the call shape differs:

  - Claude Code: `Workflow({ scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/explore-deepdive.js", args })`
  - pi: the `pi-dynamic-workflows` extension registers a `workflow` tool — `workflow({ name: "explore-deepdive", description, scriptPath: <this skill dir>/workflows/explore-deepdive.js, args })`; `scriptPath` resolves against the session cwd, so pass the absolute path to the bundled copy. `workflow` appears in the session's native tool set, NOT via MCP. The `workflow` tool is registered lazily: it exists only after `/workflow` has been used in the session (or an eager-registration extension is installed). If `workflow` is absent from the tool set, do NOT search MCP or improvise — ask the user to run `/workflow` once, or use the fallback
  - Any other host exposing a JS workflow runner with `agent()`/`parallel()`: same script, its own call shape
  - The script fans out one researcher per approach with structured pros/cons/fit
  - `args`: `{ problem, constraints, successCriteria, approaches: [{ name, description }] }`

  - Surface the workflow's `log()` lines as progress
  - Feed the returned `approaches[]` into `consolidated-report`
  - The workflow owns dispatch — do NOT also run the inline fallback

- Fallback — ONLY when no workflow runner exists on this host (e.g. OpenAI Codex): read `references/fallback-dispatch.md` and follow its `agent-selection` then `parallel-deep-dispatch` sections

</section>

<section id="consolidated-report">

- After all deep agents return, produce consolidated report
- If the workflow returns `stats.researched < stats.requested`, MUST name the approaches that failed and ask whether to re-run them before presenting
- Comparison table:
  ```
  | Approach | Pros | Cons | Fit |
  |---|---|---|---|
  ```
- `Conflicts` section — where agents cite contradicting evidence; state each side
- `Recommended approach` — prioritized pick with rationale; cite supporting evidence
- MUST cite sources where agents returned citations
- MUST present report then stop; ask user which direction to pursue
- MUST NOT begin implementation

</section>

<section id="guardrails">

- MUST gather and confirm problem context before any agent dispatch
- MUST clarify ambiguity before shallow scan
- MUST confirm shallow results with user before deep dispatch
- MUST dispatch deep research via the `explore-deepdive` workflow when a workflow runner is available; else dispatch deep agents in parallel (single message, multiple tool uses)
- MUST keep all findings local in chat only
- MUST NOT post to Slack, GitHub, Jira, or any external system unless user explicitly authorizes
- MUST NOT implement chosen approach — recommendation only
- MUST NOT proceed through any gate without explicit user confirmation
- The bundled persona in `references/personas/` always provides a fallback researcher — a missing named subagent is never a reason to stop; if the platform cannot spawn subagents at all → MUST stop and tell user; never inline-impersonate a researcher in the main thread

</section>
