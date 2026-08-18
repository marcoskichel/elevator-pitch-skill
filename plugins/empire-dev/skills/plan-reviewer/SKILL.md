---
name: plan-reviewer
description: >
  Trigger when user says: "plan review", "review the plan", "review this plan",
  "plan reviewer", "check the plan against the spec", "does the plan match the
  spec", "adversarial plan review", "audit the plan", "validate the plan",
  "/empire-dev:plan-reviewer". Dispatches an adversarial review of an
  implementation plan against its spec: flags plan parts that contradict the
  spec (wrong/incorrect), spec requirements the plan misses and plan scope the
  spec never asked for (unspecified), and plan parts too vague to implement
  (ambiguous). Findings stay local — never posted externally.
compatibility: Dispatches parallel adversarial reviewers. Runs in Claude Code, pi, and OpenAI Codex; bundled workflow script plus a documented inline fallback keep it self-contained.
---

<section id="target-detection">

- Two inputs required: the PLAN (under review) and the SPEC (source of truth)
- Infer both from conversation context first:
  - Files just written or referenced this session (plan `.md`, spec `.md`, issue text, PRD)
  - Explicit user mention ("the plan in docs/plans/x.md", "against issue #42", "the spec above")
  - A plan produced earlier in this conversation
- Spec forms: spec file, PRD, ticket/issue body, requirements section, or the user's original request restated in chat
- If either input is missing or ambiguous → ASK; offer concrete candidates found in the repo or conversation
- MUST state which document is plan and which is spec before dispatch
- Read both documents fully in the main thread; pass their full text to reviewers — reviewers MUST NOT re-fetch

</section>

<section id="no-external-writes">

- NEVER post findings to GitHub, issue trackers, or anywhere external
- NEVER edit the plan or spec without explicit user instruction after the report
- All reports stay local in chat only

</section>

<section id="review-angles">

- Three fixed adversarial angles, always all three — no roster selection needed:

  | Angle                | Hunts for                                                                                | issueType                 |
  | -------------------- | ---------------------------------------------------------------------------------------- | ------------------------- |
  | contradiction-hunter | plan steps that contradict, misread, or violate the spec (wrong/incorrect)               | `contradiction`           |
  | coverage-auditor     | spec requirements with no covering plan step; plan scope with no basis in the spec       | `omission`, `unsupported` |
  | ambiguity-prober     | plan parts two implementers would build differently; undefined terms; deferred decisions | `ambiguity`               |

- Reviewers are adversarial: the plan is on trial, the spec is truth; every finding must quote the plan text (`planRef`) and, where applicable, the spec text (`specRef`)
- Every non-nit finding gets one independent verifier that can rule it `invalid`; verified severity wins

</section>

<section id="dispatch-mode">

- Preferred — a workflow runner is available; the same script runs on every runner, only the call shape differs:

  - Claude Code: `Workflow({ scriptPath: "${CLAUDE_PLUGIN_ROOT}/workflows/plan-reviewer.js", args })`
  - pi: the `pi-dynamic-workflows` extension registers a `workflow` tool — `workflow({ name: "plan-reviewer", description, scriptPath: <this skill dir>/workflows/plan-reviewer.js, args })`; `scriptPath` resolves against the session cwd, so pass the absolute path to the bundled copy. `workflow` appears in the session's native tool set, NOT via MCP, and is registered lazily: it exists only after `/workflow` has been used in the session (or an eager-registration extension is installed). If `workflow` is absent, do NOT search MCP or improvise — ask the user to run `/workflow` once, or use the fallback
  - Any other host exposing a JS workflow runner with `agent()`/`parallel()`: same script, its own call shape
  - `args`:

    ```
    { plan, spec, context?, reviewerModel?, verifierModel? }
    ```

  - `plan`/`spec` = full document text read in `target-detection`; `context` = optional extra background (repo conventions, prior decisions, user constraints)
  - Model defaults: reviewers on a fast mid-tier model (`sonnet`), verifiers on a cheap fast one (`haiku`). Hosts that reject bare aliases (pi expects `provider/model-id`, e.g. `anthropic/claude-haiku-4-5`): pass resolvable ids via `reviewerModel`/`verifierModel` — an unresolvable model silently kills every agent and the run returns 0 reviewers
  - Run in the background when the runner supports it (pi: pass `background: true`): dispatch, tell the user the review is running, render the report when the completion message arrives. Do NOT poll or sleep. If the run dies, resume with `resumeFromRunId` instead of re-dispatching
  - Set generous run-level caps: `maxCost: 10` (or `maxTokens` where cost is unavailable); on pi also pass a run `timeout` well above the per-agent ceilings
  - Surface the workflow's `log()` lines as progress
  - The workflow owns dispatch, verification, and grouping — render its output, don't recompute

- Fallback — ONLY when no workflow runner exists on this host (e.g. OpenAI Codex):
  1. Spawn the three angle reviewers in parallel (Claude Code: the `Agent` tool; other agents: their spawn mechanism). Brief each with: its angle description from `review-angles`, the full plan and spec text, the severity rubric (`blocker` / `should-fix` / `nit`), and the required per-finding fields (`planRef`, `specRef`, `issueType`, `problem`, `suggestion`). Instruct: adversarial stance, quote-grounded findings only, empty list is a valid result, structured findings list as output
  2. After all three return, spawn one verifier per non-nit finding in parallel on a cheap fast model. Brief each with the plan, the spec, and exactly one finding; verdict = `blocker` / `should-fix` / `nit` / `invalid` + one-sentence rationale
  3. Drop `invalid` findings into the Rejected section; surviving findings take the verifier's severity
- If the platform cannot spawn subagents at all → MUST stop and tell user; never inline-impersonate reviewers or verifiers in the main thread
- MUST NOT fabricate reviewer or verifier findings inside the main thread

</section>

<section id="report">

- Render confirmed findings grouped by issue type, ordered blocker → should-fix → nit within each group:

  ```
  ## Verdict
  <one line: plan is sound / needs revision / contradicts spec — based on blocker count>

  ## Wrong (contradicts spec)
  - [<severity>] <planRef> — <problem>
    Spec: <specRef>
    Fix: <suggestion>

  ## Unspecified
  ### Spec requirements the plan misses
  - [<severity>] <specRef> — <problem>
    Fix: <suggestion>
  ### Plan scope the spec never asked for
  - [<severity>] <planRef> — <problem>
    Fix: <suggestion>

  ## Ambiguous
  - [<severity>] <planRef> — <problem>
    Fix: <suggestion>

  ## Rejected by verification
  - <planRef> — <original problem> — <verifier rationale>

  ## Unverified
  - <as confirmed rows, marked (unverified), specialist severity kept>
  ```

- Omit any section with no entries
- Verdict rule: any confirmed `blocker` → "needs revision before implementation"; contradictions dominate the one-line summary
- Findings in `Rejected by verification` MUST NOT drive the verdict

</section>

<section id="confirmation-gate">

- After the report, ask user whether to apply fixes to the plan
- MUST wait for user reply before editing the plan
- Apply only chosen fixes; the spec is never edited

</section>
