---
name: team-review
description: >
  Trigger when user says: "team review", "have specialists review", "review my
  changes", "re-review", "review again", "another pass", "ask the team",
  "specialist review", "/empire-dev:team-review", "have the team look at this",
  "get specialists to review", "run a team review", "do a specialist review".
  Spawns parallel specialist subagents to review diffs and consolidates findings.
  Never posts to GitHub.
compatibility: Dispatches parallel review subagents. Runs in Claude Code and OpenAI Codex; bundled personas keep it self-contained when no named subagents are installed.
---

<section id="intent-gate">

- Trigger phrases split into two classes:
  - Strong: "team review", "specialist review", "have specialists", "ask the team", "parallel review", "have the team look", "/empire-dev:team-review", "re-review", "another pass"
  - Weak: "review my changes", "review again", "look at this"
- If user used a Strong phrase → proceed without confirmation
- If user used only a Weak phrase → MUST confirm before dispatch:
  - "Run a parallel team review (3–4 specialists), or a single-pass review?"
  - Default to single-pass on ambiguity; dispatch a team review only when user explicitly opts in
- MUST NOT silently dispatch a multi-agent review on weak phrasing alone

</section>

<section id="target-detection">

- Infer target from conversation context first
- Signals to read:
  - Files just edited this session
  - Recent tool calls touching specific paths
  - Explicit user mention ("the auth changes", "this PR", "uncommitted work")
  - Last commit topic if user references it
  - Current task scope from todos or plan
- No default fallback chain
- If conversation gives clear scope → use it (specific files, commits, branch range)
- If signals conflict or ambiguous → ASK user; offer concrete options:
  - Option A: files X, Y just edited
  - Option B: open PR #N
  - Option C: uncommitted diff
  - Option D: branch vs base
- MUST state inferred target + evidence before dispatch
- MUST confirm with user when not certain

</section>

<section id="no-github-writes">

- NEVER run `gh pr review`, `gh pr comment`, `gh pr edit`
- NEVER post inline PR comments
- NEVER write findings to GitHub in any form
- All reports stay local in chat only

</section>

<section id="context-prep">

- Prepare shared context ONCE in the main thread before dispatch; push it into every brief — subagents MUST NOT re-fetch what the main thread already holds
- Prepare:
  - Diff text + changed-file list (`git diff` / `gh pr diff`)
  - `CONTEXT.md` vocabulary from repo root if present — reviewers MUST use project terms verbatim
  - Summaries of ADRs from `docs/adr/` touching changed paths, if present
  - If `CONTEXT.md`/ADRs absent, proceed without them
- Overlap prep with gates: when asking the user anything (target or roster confirmation), run this prep in the SAME turn as the question → dispatch is instant on confirmation

</section>

<section id="specialist-selection">

- Inspect diff; pick 3–4 specialists matching the strongest change signals — hard cap 4
- More signals than roster slots → fold weaker signals into the closest specialist's brief (e.g. performance checklist into the generalist's brief), never grow the roster
- Two ways to source each specialist; prefer the first, always have the second:
  - Named subagent — if the platform exposes specialist subagents, inspect what is available and pick the best match (Claude Code: the `Agent` tool's `subagent_type`; other agents: their own spawn mechanism)
  - Bundled persona — brief a general-purpose subagent with the matching persona in `references/personas/<name>.md`; use when no named subagent fits or the platform has no subagent registry
- Agent names vary by environment; never assume a specific named agent exists — the bundled personas guarantee the roster can always be filled
- For each signal, pick the best-matching source; if multiple fit, prefer the most specific; if none fit, use the general `code-reviewer` persona
- Signals to detect in the diff:
  - Language/framework — dominant language or framework of changed files
  - Security surface — auth, crypto, secrets, permissions, input handling
  - Architectural change — new module or package boundaries, dependency shifts, interface redesigns
  - Test changes — test files added or modified
  - Performance hotspot — hot paths, DB queries, batching, caching, resource allocation
  - Debugging need — complex logic, non-obvious control flow, subtle state mutations
  - Structural growth — file sprawl, new branching bolted into existing flows, wrapper/indirection layers, duplicated helpers (→ `simplifier`)
  - Generalist coverage — always include at least one general code-reviewer agent to anchor the roster
- MUST list chosen specialists (named `subagent_type` or persona filename) + one-line rationale per pick BEFORE dispatch
- If confident in every pick (clear signal-to-agent fit, no ambiguity) → dispatch immediately; user may interrupt mid-flight
- If uncertain about any pick (multiple candidates equally fit, no clear-fit agent for a signal, ambiguous diff scope) → MUST confirm roster with user before dispatch; allow swaps, additions, removals

</section>

<section id="dispatch-mode">

- After roster selection, dispatch one of two ways
- Preferred — a workflow runner is available; the same script runs on every runner, only the call shape differs:

  - Claude Code: `Workflow({ scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/team-review.js", args })`
  - pi: the `pi-dynamic-workflows` extension registers a `workflow` tool — `workflow({ name: "team-review", description, scriptPath: <this skill dir>/workflows/team-review.js, args })`; `scriptPath` resolves against the session cwd, so pass the absolute path to the bundled copy; pass the prepared context through the tool's `args` parameter, never baked into the script text. `workflow` appears in the session's native tool set, NOT via MCP. The `workflow` tool is registered lazily: it exists only after `/workflow` has been used in the session (or an eager-registration extension is installed). If `workflow` is absent from the tool set, do NOT search MCP or improvise — ask the user to run `/workflow` once, or use the fallback
  - Any other host exposing a JS workflow runner with `agent()`/`parallel()`: same script, its own call shape
  - The script fans out specialists with structured output, dispatches one verifier per non-nit finding EAGERLY as each specialist returns (no cross-wave barrier), and computes consensus tiers deterministically in JS
  - `args` in every case:

    ```
    {
      diff, changedFiles, intent, vocabulary, adrs,
      roster: [{ name, persona?, agentType?, model? }],
      rereviewNote?, specialistModel?, verifierModel?,
    }
    ```

  - `diff` = the prepared diff text from `context-prep`; `vocabulary`/`adrs` = the prepared context blocks
  - `persona` = the full text of `references/personas/<name>.md`, read before dispatch — always pass it unless `agentType` is set
  - `agentType` = a named agent definition, ONLY when verified to exist on this platform; an unknown name aborts that specialist and loses its whole review
  - `model` defaults to a fast mid-tier model (`sonnet`); verifiers always run a cheap fast model. Pass `model` per specialist only when a pick genuinely needs a stronger one — reviewer latency is max-of-N, so one slow specialist stalls the whole barrier
  - Hosts that reject bare aliases like `sonnet`/`haiku` (pi expects `provider/model-id`, e.g. `anthropic/claude-haiku-4-5`): pass resolvable ids via `specialistModel`/`verifierModel` — an unresolvable model silently kills every agent and the run returns `0/N agents succeeded`
  - The script gives every specialist and verifier a generous per-agent timeout with a built-in grace period, and each brief states its own budget (work minutes + grace window) so the agent paces itself and returns partial findings instead of timing out empty
  - Run in the background when the runner supports it (pi: pass `background: true` — the call returns immediately with a run id and a workflow-complete message arrives when done): dispatch, tell the user the review is running, and render the report only when the completion message arrives. Do NOT poll or sleep while waiting. If the run dies, resume with `resumeFromRunId` instead of re-dispatching from scratch
  - Set generous run-level caps on the workflow tool call — the review is worth the spend: `maxCost: 15` (or `maxTokens` where cost is unavailable); on pi also pass a run `timeout` well above the per-agent ceilings so the run never dies before its slowest agent
  - Re-review: pass prior findings, user decisions, and the new diff as `rereviewNote`
  - Surface the workflow's `log()` lines as progress
  - Feed the returned tiers into `consolidated-report` — tier math is already done; render, don't recompute
  - The workflow owns dispatch and tiering — do NOT also run the inline fallback

- Fallback — ONLY when no workflow runner exists on this host (e.g. OpenAI Codex): read `references/fallback-dispatch.md` and follow its `parallel-dispatch` then `verification-stage` sections; slower path (specialists and verifiers run as two hard barriers)
- A runner that only accepts an inline script (no `scriptPath`): author the fan-out inline, mirroring the bundled script — one `agent()` per roster entry inside `parallel()` with the finding `schema`, one verifier `agent()` per non-consensus non-nit finding on a fast `model` with the verdict `schema`, tiers computed in the script

</section>

<section id="rereview-mode">

- Trigger: user says "re-review", "review again", "another pass"
- MUST use same roster as prior review; scroll back in conversation to find it
- If prior roster cannot be located (long conversation, summarization, ambiguity) → MUST ask user to confirm the roster before dispatch; do NOT improvise a new roster silently
- Pass each specialist:
  - Their prior review findings
  - User's responses or decisions since last review
  - New diff (what changed since last review)
  - Instruction: surface unresolved prior issues + new issues only
- Same output format as initial review

</section>

<section id="consolidated-report">

- After the workflow returns (or, in inline fallback, after specialists and all verifiers return), produce consolidated report
- Workflow mode: render the returned tiers directly; do NOT recompute merging or severity. List any `unverified` entries (verifier died) under their tier with an `(unverified)` marker, keeping specialist severity
- Summary table:

  ```
  | Specialist | Must-fix | Should-fix | Nits |
  |---|---|---|---|
  ```

- Drop any finding its verifier ruled `invalid` from every section except `Rejected by verification`
- For surviving findings, use the verifier's severity (`must-fix`/`should-fix`/`nit`) for Corroborated and Single-source entries; Consensus entries keep each specialist's original severity (Consensus skips verification)
- Required report structure:

  ```
  ## Consensus  (> M/2 and ≥ 3 specialists agree)
  ### Must-fix
  <file:line-range> [`<category>`] — <merged suggestion>  ×N/M

  ### Should-fix
  ...

  ### Nits
  ...

  ## Corroborated  (≥ 2 specialists — verified)
  ### Must-fix
  <file:line-range> [`<category>`] — <merged suggestion>  ×K  [<specialist-A>, <specialist-B>]
  ...

  ## Single-source  (1 specialist — verified)
  ### Must-fix
  <file:line-range> [`<category>`] — <suggestion>  [<specialist>]
  ...

  ## Rejected by verification
  <file:line-range> [`<category>`] — <original suggestion> — <verifier rationale>

  ## Conflicts
  <file:line-range> — <specialist-A says X> vs <specialist-B says Y>

  ## Recommended actions
  1. <action> — <rationale referencing tier + verified severity>
  ...
  ```

- Omit any tier or severity heading that has no entries
- Prioritize Recommended actions by verified severity first (must-fix > should-fix > nit), then Consensus before Corroborated before Single-source as a tie-break within the same severity
- Any finding present in `Rejected by verification` MUST NOT appear in Recommended actions

</section>

<section id="confirmation-gate">

- Present recommended actions; ask user which to apply
- MUST wait for user reply before implementing anything
- Implement only chosen fixes
- One atomic commit per logical fix (follow repo git rules)

</section>

<section id="agent-availability">

- The bundled personas in `references/personas/` always provide a fallback roster — a missing named subagent is never a reason to stop
- If the platform cannot spawn subagents at all → MUST stop and tell user; never inline-impersonate a specialist or verifier in the main thread
- MUST NOT fabricate specialist or verifier findings inside the main thread

</section>
