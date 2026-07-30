# empire-dev

Development collaboration: parallel specialist code review, pre-implementation diagnostics (design, architecture, task breakdown), plus a bundled roster of dev subagents.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-dev@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Skills

### `team-review`

Spawn parallel specialist subagents to review a diff or PR, then aggregate findings into a tiered, verified report (Consensus / Corroborated / Single-source). The skill detects signals in the diff (language, security surface, architectural change, perf hotspots, tests), picks 3–4 specialists from the available roster (weaker signals fold into broader briefs), dispatches them in parallel, then votes findings by `(file, line-range, category)` match. Findings below the consensus threshold (strict majority and at least 3 specialists) each get their own independent verifier agent — the bundled fast `finding-verifier` by default — dispatched in parallel (one per finding), ruling valid/invalid against a fixed severity rubric, blind to specialist count, so a real issue caught by only one specialist isn't buried just for being single-source. Built for speed: the diff, `CONTEXT.md` vocabulary, and relevant `docs/adr/` summaries are prepared once and inlined into every brief (verifiers get just their finding's hunk), so subagents skip redundant repo reads; prep overlaps any confirmation question. Runs via the bundled `team-review.js` workflow when the Workflow tool is available — structured specialist output, verifiers dispatched eagerly as each specialist returns (no cross-wave barrier), deterministic tier math in JS — with a documented inline-Agent fallback. Findings stay local — never posted to GitHub.

**Triggers (strong, dispatch immediately):** "team review", "specialist review", "have specialists review", "ask the team", "parallel review", "have the team look", "re-review", "another pass".

**Triggers (weak, skill confirms before dispatch):** "review my changes", "review again", "look at this".

```mermaid
flowchart LR
  diff[Diff] --> roster[Pick specialists]
  roster --> dispatch[Parallel review]
  dispatch --> vote[Vote + tier]
  vote --> verify[Verify non-consensus]
  verify --> report[Report]
```

**Source:** [`skills/team-review/SKILL.md`](skills/team-review/SKILL.md)

### `socratic-pr-review`

Review a PR in the Socratic style: ask the genuine, curious question a teammate would, surfacing each issue (or clarifying intent) instead of dictating the fix. It first tells you, in plain words, what the PR does — parallel agents read the description, the diff, and how it wires into existing code — then gives a quick read on the direction, flagging tradeoffs and proposing a better alternative only when one is clearly better. Then it runs `team-review`, converts the recommended actions into short question-style inline comments, re-checks every comment against the current code (with optional web research), and walks them past you one at a time, each with a short note on the code it touches so you can weigh in with authority. It confirms sparingly: an obvious target isn't re-confirmed, and the verdict (approve / request changes / comment) plus summary and destination are settled in a single confirmation before it posts the entire review in one GitHub API call. This is the one empire-dev skill that writes to GitHub, and only after you OK the comments and the verdict. Comments stay short (ideally under 150 chars), omit fix suggestions unless unambiguous, and use no dashes or emojis.

**Triggers:** "socratic review", "socratic pr review", "socratic code review", "review this PR socratically", "review the PR with questions", "ask questions on the PR", "question-style review", "leave socratic comments", "/empire-dev:socratic-pr-review".

```mermaid
flowchart LR
  pr[PR] --> what[What it does]
  what --> dir[Check direction]
  dir --> tr[team-review]
  tr --> draft[Draft questions]
  draft --> recheck[Re-check vs code]
  recheck --> walk[Walk 1 by 1 + context]
  walk --> verdict[Verdict + post]
```

**Source:** [`skills/socratic-pr-review/SKILL.md`](skills/socratic-pr-review/SKILL.md)

### `address-review`

Address PR review comments end to end. Every unresolved review thread goes through an adversarial pipeline: a verifier per comment tries to refute it against the current code (invalid comments get a pushback reply instead of a change), a strategist decides whether the reviewer's proposed change or a better alternative is the right fix, any alternative is adversarially rechecked (refuted alternatives revert to the reviewer's proposal), then fixes are implemented in parallel, grouped by predicted file sets so parallel agents avoid colliding. A single compact TLDR — one row per comment with its verdict and draft reply — is the one confirmation gate; after it, the skill commits per fix group, pushes to the PR branch, and replies to every comment in a direct tone (1–2 short sentences, no dashes, no semicolons, no filler). Runs via the bundled `address-review.js` workflow when the Workflow tool is available, with a documented inline-Agent fallback.

**Triggers:** "address review", "address review comments", "address PR comments", "handle review comments", "fix review comments", "respond to the review", "reply to review comments", "resolve review comments", "/empire-dev:address-review".

```mermaid
flowchart LR
  pr[PR threads] --> verify[Adversarial verify]
  verify --> eval[Evaluate fix]
  eval --> recheck[Recheck alternatives]
  recheck --> fix[Fix in parallel]
  fix --> gate[TLDR gate]
  gate --> ship[Commit + push + reply]
```

**Source:** [`skills/address-review/SKILL.md`](skills/address-review/SKILL.md)

### `handoff`

Autonomously drive one task from intent to a labelled PR with green CI. Chains the workflow end-to-end: open a worktree, plan (via `superpowers:writing-plans` when a spec exists), implement, run `team-review`, auto-apply consensus fixes while flagging low-confidence/conflicting/behaviour-changing ones, open the PR (body via `pr-description`), watch CI in a bounded fix loop, and assign labels from the repo's actual label set. Invoking the skill is the ship-intent signal — it authorizes push and PR creation without per-step confirmation — but it hard-stops on ambiguous requirements, destructive/irreversible actions, security calls, scope explosions, and external side effects. Judgment calls are flagged for human review in a "Decisions & flags" PR section and the final chat report rather than guessed silently.

**Triggers:** "handoff this", "take this to a PR", "drive this to done", "implement and ship this", "do the whole thing", "run this autonomously", "take it from here", "/empire-dev:handoff".

```mermaid
flowchart LR
  spec[Spec?] --> plan[Plan]
  plan --> impl[Implement]
  impl --> review[team-review]
  review --> address[Address + flag]
  address --> pr[Open PR]
  pr --> ci[Watch CI]
  ci --> label[Label]
```

**Source:** [`skills/handoff/SKILL.md`](skills/handoff/SKILL.md)

### `weigh`

Systematically evaluate architecture decisions, document trade-offs, and select appropriate patterns for context. Generates weighted decision matrices and writes ADRs to `docs/adr/NNNN-<slug>.md` with LLM-queryable frontmatter (`adr`, `title`, `date`, `status`, `supersedes`, `tags`, `modules`). Applies refactoring patterns (Branch by Abstraction, Strangler Fig, Parallel Run). Reads `CONTEXT.md` and existing ADRs before analysis. Findings stay local.

**Triggers:** "architecture decision", "ADR", "which pattern should I use", "evaluate trade-offs", "technology choice", "design pattern selection", "weigh the options", "/empire-dev:weigh".

**Source:** [`skills/weigh/SKILL.md`](skills/weigh/SKILL.md)

### `shape`

Diagnose system design problems across seven states — from no requirements clarity through validated design with walking skeleton defined. Prevents over-engineering and under-engineering; surfaces missing integration points; drives toward a thin end-to-end path before full build-out. Reads `CONTEXT.md` and `docs/adr/` if present to ground analysis in project vocabulary and prior decisions. Findings stay local.

**Triggers:** "system design", "how should I structure this", "too much abstraction", "under-engineered", "where do I start building", "design this system", "walking skeleton", "/empire-dev:shape".

**Source:** [`skills/shape/SKILL.md`](skills/shape/SKILL.md)

### `slice`

Transform overwhelming development tasks into manageable, independently deliverable units. Diagnoses six failure states (too big, no entry point, dependency tangles, no done criteria, scope creep, spike needed) and applies decomposition patterns: vertical slicing, walking skeleton, tracer bullet. Reads `CONTEXT.md` and `docs/adr/` if present to use project vocabulary throughout. Includes Fibonacci sizing and three-point estimation.

**Triggers:** "task too big", "can't estimate", "overwhelmed by scope", "where do I start", "break this down", "epic needs breakdown", "slice this up", "/empire-dev:slice".

**Source:** [`skills/slice/SKILL.md`](skills/slice/SKILL.md)

## Bundled agents

Code review:

| Agent                  | Use                                              |
| ---------------------- | ------------------------------------------------ |
| `code-reviewer`        | Generalist code review (security, perf, quality) |
| `debugger`             | Root-cause analysis of errors and test failures  |
| `test-automator`       | Test strategy, frameworks, TDD, CI quality gates |
| `security-auditor`     | Auth, crypto, OWASP, threat modeling, compliance |
| `architect-review`     | Clean architecture, microservices, DDD, SOLID    |
| `performance-engineer` | Profiling, bottlenecks, caching, observability   |
| `finding-verifier`     | Single-finding adjudication for team-review      |

Paradigm specialists:

| Agent                           | Use                                                       |
| ------------------------------- | --------------------------------------------------------- |
| `functional-programming-expert` | Purity, immutability, totality, composition, ADT modeling |
| `concurrency-reviewer`          | Race conditions, deadlocks, async / await correctness     |
| `type-system-expert`            | Type design, invariants, generics, GADTs, branded types   |

Domain experts:

| Agent                  | Use                                                  |
| ---------------------- | ---------------------------------------------------- |
| `blockchain-developer` | Smart contracts, DeFi, Web3, gas optimization, audit |
| `ai-engineer`          | LLM apps, RAG, agents, prompts, vector search        |

The `team-review` skill auto-discovers whatever specialist subagents are installed and picks the best match per task. If your environment has more specialized subagents from another marketplace, the skill will use them.

## Upstream attribution

- Bundled agents: [`agents/NOTICE.md`](agents/NOTICE.md)
- Bundled skills: [`skills/NOTICE.md`](skills/NOTICE.md)
