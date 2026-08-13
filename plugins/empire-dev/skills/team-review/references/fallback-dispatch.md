# Inline fallback dispatch

Use ONLY when no JS workflow runner is available (see `dispatch-mode` in SKILL.md). Two hard barriers: all specialists, then all verifiers.

<section id="parallel-dispatch">

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
- MUST instruct the specialist to return the RAW schema object as its final output — never wrapped in evidence blocks, notes, or prose; a wrapped response fails parsing and the whole review is lost
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

<section id="verification-stage">

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
