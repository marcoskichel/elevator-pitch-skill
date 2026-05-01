# AGENTS.md

This file provides guidance for AI agents working with code in this repository.

## Repo nature

- Claude Code plugin marketplace. No build, no lint, no test harness.
- Single marketplace (`.claude-plugin/marketplace.json`) exposes four plugins: `empire` (meta bundle), `empire-git`, `empire-team`, `empire-product`.
- Plugin content = markdown SKILL files + one bash bootstrap script (in `empire-git`).
- Validation = install-and-invoke in Claude Code. No CI suite.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest. Each `plugins[]` entry points to one of the `plugins/empire-*` dirs.
- `plugins/empire-meta/.claude-plugin/plugin.json` — meta plugin (`name: "empire"`). Empty skills dir. Uses `dependencies` field to auto-install the three sub-plugins.
- `plugins/empire-git/` — git workflow skills (`worktree-*`, `pr-description`) + `scripts/worktree-setup.sh`.
- `plugins/empire-team/` — parallel subagent skills (`review`, `research`).
- `plugins/empire-product/` — product comms skills (`pitch`, future: competitive analysis, docs).
- `plugins/empire-*/skills/<skill-name>/SKILL.md` — one dir per skill. Skill name in frontmatter MUST match dir name.
- `docs/superpowers/{specs,plans}/` — gitignored. Local-only design notes. Never commit.

## Skill authoring rules

- Frontmatter required: `name`, `description`. Optional: `model`, `allowed-tools`, `argument-hint`, `disable-model-invocation`.
- `description` MUST list trigger phrases verbatim — Claude auto-route uses them.
- Reference bundled scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/<file>.sh`. Never hardcode repo paths.
- Users invoke skills as `/<plugin>:<skill-name>` once installed. Plugin namespaces: `empire-git`, `empire-team`, `empire-product`. The meta `empire` plugin contributes no skills.
- After editing a SKILL.md, also update the matching section in `README.md` if triggers, args, or behavior changed.

## Adding a new skill

1. Pick the right plugin (`empire-git`, `empire-team`, or `empire-product`). Create a new plugin only if the skill clearly fits no existing namespace.
2. Create `plugins/<plugin>/skills/<name>/SKILL.md` with frontmatter + body. Frontmatter `name` MUST match dir name.
3. Add a section to `README.md` under the matching plugin heading, mirroring existing entries (description, triggers, source link).
4. If shipping a script, drop it in `plugins/<plugin>/scripts/` and `chmod +x`.
5. Bump the version in `plugins/<plugin>/.claude-plugin/plugin.json`. If the change is user-visible across multiple sub-plugins, also bump `plugins/empire-meta/.claude-plugin/plugin.json`.
6. Test by installing the marketplace locally in Claude Code: `/plugin marketplace add <local-path-or-fork>` then `/plugin install <plugin>@empire` (or `empire@empire` for the bundle).

## Conventions

- Kebab-case for skill dirs and script filenames.
- Conventional Commits with optional scope. Use the plugin name as scope: `empire-git`, `empire-team`, `empire-product`, `empire-meta`. Use `marketplace` for marketplace-level changes. Use `!` for breaking marketplace/manifest changes.
- Skill prose = imperative mood, MUST/SHOULD/MAY, fragments. See `plugins/empire-team/skills/review/SKILL.md` for section-tag style.
- Scripts use `set -euo pipefail`, color-coded `info/warn/die/success` helpers (pattern in `worktree-setup.sh`).

## What this repo is NOT

- Not a Node/Python/Go project. No `package.json`, no `pyproject.toml`. Don't add a build system unless asked.
- Not a backend. Skills run inside Claude Code on the user's machine. Assume zero server-side state.
