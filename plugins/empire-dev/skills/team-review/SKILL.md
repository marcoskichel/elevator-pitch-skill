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
  - pi (`pi-dynamic-workflow`): `workflow({ name: "team-review", description, scriptPath: <this skill dir>/workflows/team-review.js, args })` — `scriptPath` resolves against the session cwd, so pass the absolute path to the bundled copy
  - Any other host exposing a JS workflow runner with `agent()`/`parallel()`: same script, its own call shape
  - The script fans out specialists with structured output, dispatches one verifier per non-nit finding EAGERLY as each specialist returns (no cross-wave barrier), and computes consensus tiers deterministically in JS
  - `args` in every case:

    ```
    {
      diff, changedFiles, intent, vocabulary, adrs,
      roster: [{ name, persona?, agentType?, model? }],
      rereviewNote?,
    }
    ```

  - `diff` = the prepared diff text from `context-prep`; `vocabulary`/`adrs` = the prepared context blocks
  - `persona` = the full text of `references/personas/<name>.md`, read before dispatch — always pass it unless `agentType` is set
  - `agentType` = a named agent definition, ONLY when verified to exist on this platform; an unknown name aborts that specialist and loses its whole review
  - `model` defaults to a fast mid-tier model (`sonnet`); verifiers always run a cheap fast model. Pass `model` per specialist only when a pick genuinely needs a stronger one — reviewer latency is max-of-N, so one slow specialist stalls the whole barrier
  - Re-review: pass prior findings, user decisions, and the new diff as `rereviewNote`
  - Surface the workflow's `log()` lines as progress
  - Feed the returned tiers into `consolidated-report` — tier math is already done; render, don't recompute
  - Skip `parallel-dispatch` and `verification-stage` — the workflow owns dispatch and tiering

- Fallback — no workflow runner (e.g. OpenAI Codex): use `parallel-dispatch` then `verification-stage` below; it is the slower path (specialists and verifiers run as two hard barriers), so prefer a runner whenever one exists
- A runner that only accepts an inline script (no `scriptPath`): author the fan-out inline, mirroring the bundled script — one `agent()` per roster entry inside `parallel()` with the finding `schema`, one verifier `agent()` per non-consensus non-nit finding on a fast `model` with the verdict `schema`, tiers computed in the script
- MUST check for a workflow runner before falling back; the fallback exists because some hosts lack one, not as a default

</section>

<section id="parallel-dispatch">

- Inline fallback — only when the Workflow tool is unavailable (see `dispatch-mode`)
- Dispatch all specialists in parallel, one subagent per specialist (Claude Code: one message with multiple `Agent` tool calls; other agents: spawn them concurrently)
- Each specialist receives:
  - Diff text INLINED in the brief — never a bare PR number
  - Exception: diff over ~1500 changed lines → inline changed-file list + one-line-per-file summary instead; specialists fetch details themselves
  - List of changed files
  - For a persona-sourced specialist: the role and expertise from `references/personas/<name>.md`, as its instructions
  - User's stated intent (if provided)
  - `CONTEXT.md` vocabulary (read from repo root before dispatch; include if file exists, omit if absent)
  - Relevant ADRs from `docs/adr/` (include summaries of ADRs touching changed paths; omit if folder absent)
  - Output format instruction (see below)
  - "Do NOT post to GitHub. Report findings in chat only."
  - "Scope: review what the diff DOES and how it is structured; flag defects AND structural regressions in changed lines + their direct blast radius."
  - "Be ambitious. Do not stop at local cleanup — look for the reframing that makes whole branches, helpers, modes, or layers disappear. Prefer deleting complexity over rearranging it."
  - "A RESTRUCTURING proposal needs no cited defect IF it removes more code and concepts than it adds; name what disappears."
  - "An ADDITIVE suggestion (new file, abstraction, test, doc) MUST cite the specific defect in the diff it resolves; no defect cited → drop the finding."
  - "Do not rubber-stamp working code that leaves the codebase messier. Do not flood with nits — omit the Nits section entirely when you have Must-fix findings."
- Required specialist output format:

  ```
  ## Must-fix
  <file:line-range> [`<category>`] — <concrete suggestion>

  ## Should-fix
  <file:line-range> [`<category>`] — <concrete suggestion>

  ## Nits
  <file:line-range> [`<category>`] — <concrete suggestion>

  ## Praise
  <what was done well>
  ```

- `<file:line-range>` = exact line or hyphen range (e.g. `src/auth.ts:42` or `src/auth.ts:42-58`)
- `<category>` MUST be exactly one of: `correctness`, `security`, `performance`, `architecture`, `tests`, `style`, `docs`
- One finding per line; no prose paragraphs between findings
- Cap each specialist response under 400 words

### Bounding each specialist

- MUST request structured output matching the finding format (Pi: `outputSchema`;
  Claude Code inline `Agent`: require the format block verbatim)
- MUST cap tool use so the child finalizes while it still can (Pi: `toolBudget` with `soft: 40`, `hard: 60`)
- MUST cap turns with a grace window (Pi: `turnBudget` with `maxTurns: 25`, `graceTurns: 3`)
- MUST give each specialist its own output file and require appending each finding
  as it is confirmed, never batched (Pi: `output: 'review-<specialist>.md'`), so a
  killed child still leaves findings on disk
- MUST give each specialist ONE focused question, not a list of areas; fan out
  wider and narrower instead
- SHOULD drop reasoning effort to `medium` on a large diff
- MUST NOT raise the host timeout as the fix; bound the work, not the clock

A specialist that returns nothing is a failed source: report it as such, never
silently drop it, never substitute the main thread's own reading for its verdict.

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

<section id="verification-stage">

- Inline fallback — only when the Workflow tool is unavailable
- Compute match key across all specialist findings: same file path AND overlapping line-range (within ±5 lines) AND identical category
- Merge matched findings into one entry; preserve clearest suggestion wording; tally specialist count
- Tiers (let `M` = roster size):
  - `Consensus` — flagged by strict majority (> M/2) AND ≥ 3 specialists; at M = 3 that means all three
  - `Corroborated` — flagged by ≥ 2 specialists, below the Consensus threshold
  - `Single-source` — flagged by exactly 1 specialist
- Nit-severity findings skip verification — adjudication costs more than the finding is worth; they carry specialist severity
- Consensus findings skip verification
- Dispatch verifiers in PARALLEL — one subagent per Corroborated/Single-source finding, all at once (Claude Code: one message with multiple `Agent` calls)
- Each verifier adjudicates exactly ONE finding in isolation; never one verifier judging multiple findings, never a serial single-verifier pass
- Prefer the bundled `finding-verifier` agent (fast model, tuned for single-finding adjudication); else a general-purpose subagent briefed with `references/personas/finding-verifier.md`, using a different source than the finding's roster specialist; else the general `code-reviewer` persona
- Each verifier receives:
  - The diff hunk(s) covering its finding's `file:line-range` ± ~15 lines, INLINED
  - Its one finding's `file:line-range`, `category`, and suggestion text ONLY — never the tier label or specialist count
  - The fixed severity rubric below
  - "Do NOT post to GitHub. Report findings in chat only."
- Fixed severity rubric — each verifier MUST classify its finding as exactly one of:
  - `valid: must-fix` — confirmed defect breaking functionality, security, data integrity, or correctness in the changed lines or their direct blast radius
  - `valid: should-fix` — confirmed real improvement, not urgent; includes a behavior-preserving restructuring that provably removes more code and concepts than it adds
  - `valid: nit` — confirmed but cosmetic/style only
  - `invalid` — claim does not hold up against the diff, OR the proposed restructuring adds more than it removes, OR it changes behavior while claiming not to
- Required output format — each verifier returns exactly one line:

  ```
  <file:line-range> [`<category>`] — <valid: must-fix|valid: should-fix|valid: nit|invalid> — <one-sentence rationale>
  ```

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
- For surviving findings, use the verifier's severity (`must-fix`/`should-fix`/`nit`) for Corroborated and Single-source entries; Consensus entries keep each specialist's original severity (skipped verification per `verification-stage`)
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
