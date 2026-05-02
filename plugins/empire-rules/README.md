# empire-rules

Sync hand-authored skill-routing rules from installed `empire-*` plugins into a target rules file. Default target is the user-global file (`~/.claude/CLAUDE.md`) so rules apply wherever the skills do; project scope (`./AGENTS.md`) is supported for teams that share rules via version control.

Part of the [empire](../../README.md) marketplace. Auto-installed as a dependency of every other `empire-*` plugin.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-rules@empire
```

You usually do not install this plugin directly — it is pulled in automatically when you install any `empire-git`, `empire-dev`, `empire-research`, or `empire-product`, and transitively when you install the `empire` bundle.

## Skills

### `sync-rules`

Reconcile per-plugin routing snippets into either `~/.claude/CLAUDE.md` (user scope) or the project's `AGENTS.md` (project scope) between idempotent HTML-comment markers. Diff preview before write. Single confirmation.

Each `empire-*` plugin ships a `rules/AGENTS.md` snippet describing its skills and workflow conventions. `/empire-rules:sync-rules` enumerates installed plugins, aggregates snippets, and writes them into the chosen target. Re-running detects updates, additions, and orphan removals from uninstalled plugins.

Scope is auto-detected from existing markers across both candidate files. On first run with markers in neither, the skill asks where to write. Pass `--scope user|project|both` to skip the prompt.

Triggers: "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules".

Usage:

```sh
/empire-rules:sync-rules                       # auto-detect scope or prompt
/empire-rules:sync-rules --scope user          # ~/.claude/CLAUDE.md
/empire-rules:sync-rules --scope project       # ./AGENTS.md
/empire-rules:sync-rules --scope both          # write both
/empire-rules:sync-rules empire-git            # restrict to one plugin
```

Source: [`skills/sync-rules/SKILL.md`](skills/sync-rules/SKILL.md), [`scripts/sync-rules.sh`](scripts/sync-rules.sh)
