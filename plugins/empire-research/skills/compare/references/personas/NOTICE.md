# Bundled subagents — attribution

These agents are adapted from upstream open-source projects under the MIT
License. Originals live at the repos below.

## Sources

### From [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — MIT, © 2025 VoltAgent

- `research-analyst.md` — `categories/10-research-analysis/research-analyst.md`

## Local modifications

- Removed the `## Communication Protocol` section and the "Query context
  manager for..." workflow line. Upstream VoltAgent agents target their own
  multi-agent orchestration framework where a `context-manager` agent
  fields JSON-shaped queries; that framework does not exist in standalone
  Claude Code dispatch, so the protocol was dead prompt overhead. Replaced
  with "Confirm objectives... from the dispatching prompt" to reflect how
  the agent actually receives context.

## Why bundled

This agent serves as a default fallback so the `empire-research:explore` and
`empire-research:compare` skills work out of the box without requiring users
to install a separate marketplace. For richer coverage, install VoltAgent's
marketplace directly.
