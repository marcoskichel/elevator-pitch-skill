# empire-rules

Sync hand-authored skill-routing rules from installed `empire-*` plugins into the project's `AGENTS.md`.

Part of the [empire](../../README.md) marketplace. Auto-installed as a dependency of every other `empire-*` plugin.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-rules@empire
```

You usually do not install this plugin directly — it is pulled in automatically when you install any `empire-git`, `empire-dev`, `empire-research`, or `empire-product`, and transitively when you install the `empire` bundle.

## Skills

### `sync-rules`

Reconcile per-plugin routing snippets into the project's `AGENTS.md` (or `CLAUDE.md`) between idempotent HTML-comment markers. Diff preview before write. Single confirmation.

Each `empire-*` plugin ships a `rules/AGENTS.md` snippet describing its skills and workflow conventions. `/empire-rules:sync-rules` enumerates installed plugins, aggregates snippets, and writes them into your project file. Re-running detects updates, additions, and orphan removals from uninstalled plugins.

Triggers: "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules".

Usage:

```sh
/empire-rules:sync-rules           # reconcile all installed empire-* plugins
/empire-rules:sync-rules empire-git # only the empire-git block
```

Source: [`skills/sync-rules/SKILL.md`](skills/sync-rules/SKILL.md), [`scripts/sync-rules.sh`](scripts/sync-rules.sh)
