# Bundled subagents — attribution

These agents are adapted from upstream open-source projects under the MIT
License. Originals live at the repos below. Local copies have been
adjusted and had `tools:` restrictions reviewed; behavior and intent are
preserved.

## Sources

### From [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — MIT, © 2025 VoltAgent

- `research-analyst.md` — `categories/10-research-analysis/research-analyst.md`
- `competitive-analyst.md` — `categories/10-research-analysis/competitive-analyst.md`
- `project-idea-validator.md` — `categories/10-research-analysis/project-idea-validator.md`

## Local modifications

- VoltAgent `project-idea-validator.md`: removed `Write, Edit` from
  `tools:` to keep validation read-only.

## Why bundled

These agents serve as a default fallback so the `empire-research:research`
skill works out of the box without requiring users to install a separate
marketplace. For richer coverage, install VoltAgent's marketplace directly.
