---
name: team-review
description: >
  Trigger when user says: "team review", "have specialists review", "review my
  changes", "re-review", "review again", "another pass", "ask the team",
  "specialist review", "/empire-dev:team-review", "have the team look at this",
  "get specialists to review", "run a team review", "do a specialist review".
  Spawns parallel specialist subagents to review diffs and consolidates findings.
  Never posts to GitHub.
compatibility: Designed for Claude Code (or similar agents); dispatches review subagents.
---

<section id="intent-gate">

- Trigger phrases split into two classes:
  - Strong: "team review", "specialist review", "have specialists", "ask the team", "parallel review", "have the team look", "/empire-dev:team-review", "re-review", "another pass"
  - Weak: "review my changes", "review again", "look at this"
- If user used a Strong phrase → proceed without confirmation
- If user used only a Weak phrase → MUST confirm before dispatch:
  - "Run a parallel team review (3–6 specialists), or a single-pass review?"
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

<section id="domain-awareness">

Before dispatch: read `CONTEXT.md` at repo root if present and include its vocabulary in each specialist brief — reviewers MUST use project terms verbatim.
Read relevant ADRs from `docs/adr/` if present; include them in specialist briefs for architectural or design findings.
If neither exists, proceed without them.

</section>

<section id="specialist-selection">

- Inspect diff; pick 3–6 specialists matching change content
- Agent names vary by environment; do not assume a specific agent exists
- Inspect available subagents via the `Agent` tool's `subagent_type` parameter
- For each signal present in the diff, pick the available agent whose name/description best matches; if multiple candidates fit, prefer the most specific; if none fit, fall back to the most general code-reviewer-style agent available
- Signals to detect in the diff:
  - Language/framework — dominant language or framework of changed files
  - Security surface — auth, crypto, secrets, permissions, input handling
  - Architectural change — new module or package boundaries, dependency shifts, interface redesigns
  - Test changes — test files added or modified
  - Performance hotspot — hot paths, DB queries, batching, caching, resource allocation
  - Debugging need — complex logic, non-obvious control flow, subtle state mutations
  - Generalist coverage — always include at least one general code-reviewer agent to anchor the roster
- MUST list chosen specialists with their actual `subagent_type` values + one-line rationale per pick BEFORE dispatch
- If confident in every pick (clear signal-to-agent fit, no ambiguity) → dispatch immediately; user may interrupt mid-flight
- If uncertain about any pick (multiple candidates equally fit, no clear-fit agent for a signal, ambiguous diff scope) → MUST confirm roster with user before dispatch; allow swaps, additions, removals

</section>

<section id="parallel-dispatch">

- Send single message with multiple `Agent` tool calls (one per specialist)
- Each specialist receives:
  - Full diff or PR number
  - List of changed files
  - User's stated intent (if provided)
  - `CONTEXT.md` vocabulary (read from repo root before dispatch; include if file exists, omit if absent)
  - Relevant ADRs from `docs/adr/` (include summaries of ADRs touching changed paths; omit if folder absent)
  - Output format instruction (see below)
  - "Do NOT post to GitHub. Report findings in chat only."
  - "Scope: review what the diff DOES; flag defects in changed lines + their direct blast radius."
  - "Propose new abstractions, tests, or docs ONLY when the diff has a concrete defect best fixed that way; speculative 'would be cleaner' suggestions → demote to Nits or omit."
  - "Net-new additions (file, abstraction, test, doc) MUST cite the specific defect in the diff they resolve; no defect cited → drop the finding."
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

- Compute match key across all specialist findings: same file path AND overlapping line-range (within ±5 lines) AND identical category
- Merge matched findings into one entry; preserve clearest suggestion wording; tally specialist count
- Tiers (let `M` = roster size):
  - `Consensus` — flagged by strict majority (> M/2)
  - `Corroborated` — flagged by ≥ 2 specialists, below majority
  - `Single-source` — flagged by exactly 1 specialist
- Consensus findings skip verification — majority agreement is sufficient signal; verifying every finding would scale cost with total finding count instead of contested-finding count
- Dispatch ONE verifier agent covering all Corroborated + Single-source findings in a single call — never one call per finding
- Verifier MUST use a different `subagent_type` than any roster specialist where an alternative exists; otherwise use the most general code-reviewer-style agent available
- Verifier receives:
  - Full diff or PR number, list of changed files
  - Each Corroborated/Single-source finding's `file:line-range`, `category`, and suggestion text ONLY — omit tier label and specialist count so severity isn't anchored to how many specialists agreed
  - The fixed severity rubric below
  - "Do NOT post to GitHub. Report findings in chat only."
- Fixed severity rubric — verifier MUST classify each finding as exactly one of:
  - `valid: must-fix` — confirmed defect breaking functionality, security, data integrity, or correctness in the changed lines or their direct blast radius
  - `valid: should-fix` — confirmed real improvement, not urgent
  - `valid: nit` — confirmed but cosmetic/style only
  - `invalid` — claim does not hold up against the diff
- Required verifier output format:

  ```
  <file:line-range> [`<category>`] — <valid: must-fix|valid: should-fix|valid: nit|invalid> — <one-sentence rationale>
  ```

- Rationale: single-pass isolated adjudication of contested/singleton findings beats both majority vote and generic LLM-as-judge on accuracy while bounding cost to auditing non-consensus items only ("Auditing Multi-Agent LLM Reasoning Trees Outperforms Majority Vote and LLM-as-Judge", arxiv:2602.09341); distinct from iterative peer debate, so this doesn't conflict with "Debate or Vote" (arxiv:2508.17536) — that finding is about repeated debate among the _generating_ agents, not a single downstream adjudication pass

</section>

<section id="consolidated-report">

- After specialists and the verifier return, produce consolidated report
- Summary table:
  ```
  | Specialist | Must-fix | Should-fix | Nits |
  |---|---|---|---|
  ```
- Drop any finding the verifier ruled `invalid` from every section except `Rejected by verification`
- For surviving findings, use the verifier's severity (`must-fix`/`should-fix`/`nit`) for Corroborated and Single-source entries; Consensus entries keep each specialist's original severity (skipped verification per `verification-stage`)
- Required report structure:

  ```
  ## Consensus  (> M/2 specialists agree)
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

- If zero suitable code-review/specialist/verifier agents exist in the environment → MUST stop and tell user; never inline-impersonate one
- MUST NOT fabricate specialist or verifier personas inside the main thread

</section>
