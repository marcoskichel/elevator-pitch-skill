# Bundled subagents — attribution

These agents are adapted from upstream open-source projects under the MIT
License. Originals live at the repos below.

## Sources

### From [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — MIT, © 2025 VoltAgent

- `project-idea-validator.md` — `categories/10-research-analysis/project-idea-validator.md`
- `competitive-analyst.md` — `categories/10-research-analysis/competitive-analyst.md`
- `market-researcher.md` — `categories/10-research-analysis/market-researcher.md`

## Local modifications

- `project-idea-validator.md`: removed `Write, Edit` from `tools:` to keep
  validation read-only (no file mutations during pressure-testing).

## Skill references

The `recon` skill (`skills/recon/SKILL.md`) is informed by the
[0-shiv/secondstep-claude-skills competitor-analysis-claude](https://github.com/0-shiv/secondstep-claude-skills/blob/main/skills/competitor-analysis-claude/SKILL.md)
SKILL (MIT, © Shivendra Rawat). Specifically borrowed: the confidence-tag
discipline (`[Confirmed]` / `[Estimated]` / `[Inferred]`), source-attribution
requirement, freshness-dating, and ethical-scope guard. The empire `recon`
skill is a fresh implementation rather than a port, but follows the same
data-integrity principles.

## Why bundled

These agents serve as default fallbacks so the `empire-product:vet` and
`empire-product:recon` skills work out of the box without requiring users to
install a separate marketplace. For richer coverage, install VoltAgent's
marketplace directly.
