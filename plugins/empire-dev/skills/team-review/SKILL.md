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

- Prepare shared context ONCE in the main thread before dispatch; push it into every brief — subagents MUST NOT re-fetch what the main thread already holds (each re-fetch costs a serial tool turn inside the barrier)
- Prepare:
  - Diff text + changed-file list (`git diff` / `gh pr diff`)
  - `CONTEXT.md` vocabulary from repo root if present — reviewers MUST use project terms verbatim
  - Summaries of ADRs from `docs/adr/` touching changed paths, if present
  - If `CONTEXT.md`/ADRs absent, proceed without them
- Overlap prep with gates: when asking the user anything (target or roster confirmation), run this prep in the SAME turn as the question → dispatch is instant on confirmation

</section>

<section id="specialist-selection">

- Inspect diff; pick 3–4 specialists matching the strongest change signals — hard cap 4
- Rationale: the barrier waits on the slowest specialist (max-of-N grows with N) and each extra specialist adds singleton findings that each spawn a verifier; homogeneous same-model rosters show sharply diminishing recall gains past 3–4 (arxiv:2402.05120, arxiv:2602.03794)
- More signals than roster slots → fold weaker signals into the closest specialist's brief (e.g. performance checklist into the generalist's brief), never grow the roster
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

<section id="dispatch-mode">

- After roster selection, dispatch one of two ways
- Preferred — Workflow tool available:

  - Invoke the bundled workflow; it fans out specialists with structured output, dispatches one verifier per finding EAGERLY as each specialist returns (no cross-wave barrier), and computes consensus tiers deterministically in JS:

    ```
    Workflow({
      scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/team-review.js",
      args: {
        diff, changedFiles, intent, vocabulary, adrs,
        roster: [{ name, agentType, model?, effort? }],
        rereviewNote?,
      },
    })
    ```

  - `diff` = the prepared diff text from `context-prep`; `vocabulary`/`adrs` = the prepared context blocks; `agentType` = each pick's actual `subagent_type` value
  - Re-review: pass prior findings, user decisions, and the new diff as `rereviewNote`
  - Surface the workflow's `log()` lines as progress
  - Feed the returned tiers into `consolidated-report` — tier math is already done; render, don't recompute
  - Skip `parallel-dispatch` and `verification-stage` — the workflow owns dispatch and tiering

- Fallback — Workflow tool unavailable: use `parallel-dispatch` then `verification-stage` below

</section>

<section id="parallel-dispatch">

- Inline fallback — only when the Workflow tool is unavailable (see `dispatch-mode`)
- Send single message with multiple `Agent` tool calls (one per specialist)
- Each specialist receives:
  - Diff text INLINED in the brief — never a bare PR number; per-agent `gh pr diff`/file re-fetches are serial tool turns inside the barrier
  - Exception: diff over ~1500 changed lines → inline changed-file list + one-line-per-file summary instead; specialists fetch details themselves
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

- Inline fallback — only when the Workflow tool is unavailable; the workflow computes identical tiers itself
- Compute match key across all specialist findings: same file path AND overlapping line-range (within ±5 lines) AND identical category
- Merge matched findings into one entry; preserve clearest suggestion wording; tally specialist count
- Tiers (let `M` = roster size):
  - `Consensus` — flagged by strict majority (> M/2) AND ≥ 3 specialists; at M = 3 that means all three
  - `Corroborated` — flagged by ≥ 2 specialists, below the Consensus threshold
  - `Single-source` — flagged by exactly 1 specialist
- Consensus findings skip verification — ≥ 3 independent agreements is sufficient signal; the ≥ 3 floor exists because at small M a bare majority (2 of 3) is too weak to bypass adjudication
- Dispatch verifiers in PARALLEL — one `Agent` call per Corroborated/Single-source finding — in a single message
- Each verifier adjudicates exactly ONE finding in isolation; never one verifier judging multiple findings, never a serial single-verifier pass
- Prefer the bundled `finding-verifier` agent (fast model, tuned for single-finding adjudication); else any `subagent_type` different from every roster specialist; else the most general code-reviewer-style agent available
- Each verifier receives:
  - The diff hunk(s) covering its finding's `file:line-range` ± ~15 lines, INLINED — goal: adjudicate in one turn with zero tool calls; tools stay available for blast-radius checks beyond the hunk
  - Its one finding's `file:line-range`, `category`, and suggestion text ONLY — omit tier label and specialist count so severity isn't anchored to how many specialists agreed
  - The fixed severity rubric below
  - "Do NOT post to GitHub. Report findings in chat only."
- Fixed severity rubric — each verifier MUST classify its finding as exactly one of:
  - `valid: must-fix` — confirmed defect breaking functionality, security, data integrity, or correctness in the changed lines or their direct blast radius
  - `valid: should-fix` — confirmed real improvement, not urgent
  - `valid: nit` — confirmed but cosmetic/style only
  - `invalid` — claim does not hold up against the diff
- Required output format — each verifier returns exactly one line:

  ```
  <file:line-range> [`<category>`] — <valid: must-fix|valid: should-fix|valid: nit|invalid> — <one-sentence rationale>
  ```

- Rationale: per-finding isolated adjudication of contested/singleton findings beats both majority vote and generic LLM-as-judge on accuracy while bounding cost to auditing non-consensus items only ("Auditing Multi-Agent LLM Reasoning Trees Outperforms Majority Vote and LLM-as-Judge", arxiv:2602.09341); one verifier per finding preserves that isolation while cutting wall-clock latency vs a single serial pass, and removes cross-finding anchoring; distinct from iterative peer debate, so this doesn't conflict with "Debate or Vote" (arxiv:2508.17536) — that finding is about repeated debate among the _generating_ agents, not a single downstream adjudication pass

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

- If zero suitable code-review/specialist/verifier agents exist in the environment → MUST stop and tell user; never inline-impersonate one
- MUST NOT fabricate specialist or verifier personas inside the main thread

</section>
