# empire-rules

Sync hand-authored skill-routing rules from installed `empire-*` plugins into a target rules file. Default target is the user-global file (`~/.claude/CLAUDE.md`) so rules apply wherever the skills do; project scope (`./AGENTS.md`) is supported for teams that share rules via version control.

Part of the [empire](../../README.md) marketplace. Auto-installed as a dependency of every other `empire-*` plugin.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-rules@empire
```

You usually do not install this plugin directly — it is pulled in automatically when you install any of `empire-git`, `empire-dev`, `empire-research`, or `empire-product`, and transitively when you install the `empire` bundle.

## Skills

### `sync-rules`

Reconcile per-plugin routing snippets into either `~/.claude/CLAUDE.md` (user scope) or the project's `AGENTS.md` (project scope), inserted between idempotent HTML-comment markers. The skill enumerates installed `empire-*` plugins, aggregates their `rules/AGENTS.md` snippets, shows a unified diff preview, and writes only after a single confirmation. Re-running detects updates, additions, and orphan removals from uninstalled plugins.

Scope is auto-detected from existing markers across both candidate files. On first run with markers in neither, the skill asks where to write. Pass `--scope user|project|both` to skip the prompt.

**Triggers:** "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules", "refresh empire CLAUDE.md", "rewrite empire rules".

**Usage:**

```sh
/empire-rules:sync-rules                       # auto-detect scope or prompt
/empire-rules:sync-rules --scope user          # ~/.claude/CLAUDE.md
/empire-rules:sync-rules --scope project       # ./AGENTS.md
/empire-rules:sync-rules --scope both          # write both
/empire-rules:sync-rules empire-git            # restrict to one plugin
```

```mermaid
flowchart LR
  scan[Scan installed plugins] --> agg[Aggregate snippets]
  agg --> diff[Diff preview]
  diff --> write[Write to target]
```

**Source:** [`skills/sync-rules/SKILL.md`](skills/sync-rules/SKILL.md), [`scripts/sync-rules.sh`](scripts/sync-rules.sh)
