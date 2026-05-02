# Bundled subagents — attribution

These agents are adapted from upstream open-source projects under the MIT
License. Originals live at the repos below. Local copies have been trimmed
and had `tools:` restrictions added; behavior and intent are preserved.

## Sources

### From [wshobson/agents](https://github.com/wshobson/agents) — MIT, © 2024 Seth Hobson

- `code-reviewer.md` — `plugins/comprehensive-review/agents/code-reviewer.md`
- `debugger.md` — `plugins/error-diagnostics/agents/debugger.md`
- `test-automator.md` — `plugins/unit-testing/agents/test-automator.md`
- `security-auditor.md` — `plugins/comprehensive-review/agents/security-auditor.md`
- `architect-review.md` — `plugins/comprehensive-review/agents/architect-review.md`
- `performance-engineer.md` — `plugins/application-performance/agents/performance-engineer.md`
- `blockchain-developer.md` — `plugins/blockchain-web3/agents/blockchain-developer.md`
- `ai-engineer.md` — `plugins/llm-application-dev/agents/ai-engineer.md`

### From [coleam00/Archon](https://github.com/coleam00/Archon) — MIT, © 2025-2026 Cole Medin

- `type-system-expert.md` — adapted from `.claude/agents/type-design-analyzer.md`,
  extended with type-level programming language (TypeScript conditional /
  mapped types, Rust traits / phantom types, Haskell GADTs / HKTs, etc.).

### From [bradwindy/ultimate-code-review](https://github.com/bradwindy/ultimate-code-review) — MIT

- `concurrency-reviewer.md` — adapted from `agents/concurrency-reviewer.md`,
  expanded with channel / actor / message-passing patterns and Rust
  `Send + Sync` / Erlang-Elixir runtime notes.

## Greenfield (no upstream)

- `functional-programming-expert.md` — written from scratch. Reference
  patterns drawn from wshobson's `haskell-pro`, `scala-pro`, and
  `elixir-pro` (MIT, © Seth Hobson) without copying prose.

## Local modifications

- wshobson agents: added explicit `tools:` restrictions; trimmed
  language-specific and process sections that did not improve routing
  accuracy.
- Archon `type-design-analyzer.md`: renamed to `type-system-expert`,
  extended scope from pure type-design rubric to include type-system
  mechanics (HKTs, GADTs, branded / phantom types, traits, lifetimes).
- bradwindy `concurrency-reviewer.md`: removed `LSP`, `effort`, `color`
  frontmatter fields (not standard); added channel / actor / Rust /
  Erlang-Elixir patterns.

## Why bundled

These agents serve as a default fallback so the `empire-dev:team-review` skill
works out of the box without requiring users to install a separate
marketplace. For richer coverage, install upstream marketplaces directly.
