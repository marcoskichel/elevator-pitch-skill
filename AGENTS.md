# AGENTS.md

This file provides guidance for AI agents working with code in this repository.

## Repo nature

- Claude Code plugin marketplace. No build, no lint, no test harness.
- Single marketplace (`.claude-plugin/marketplace.json`) exposes five plugins: `empire` (meta bundle), `empire-git`, `empire-dev`, `empire-research`, `empire-product`. Plus `empire-rules` (utility, auto-installed as a transitive dependency).
- Plugin content = markdown SKILL files + one bash bootstrap script (in `empire-git`).
- Validation = install-and-invoke in Claude Code. No CI suite.

## Layout

- `.claude-plugin/marketplace.json` — marketplace manifest. Each `plugins[]` entry points to one of the `plugins/empire-*` dirs.
- `plugins/empire-meta/.claude-plugin/plugin.json` — meta plugin (`name: "empire"`). Empty skills dir. Uses `dependencies` field to auto-install the sub-plugins.
- `plugins/empire-git/` — git workflow skills (`worktree-*`, `pr-description`) + `scripts/worktree-setup.sh`.
- `plugins/empire-dev/` — code `review` skill plus 11 bundled dev subagents (code review, paradigms, domain experts).
- `plugins/empire-research/` — `explore` (open-ended) and `compare` (closed) research skills, with `research-analyst` as bundled fallback subagent.
- `plugins/empire-product/` — `pitch`, `vet` (idea pressure-test), and `recon` (competitor matrix) skills, plus three bundled subagents (`project-idea-validator`, `competitive-analyst`, `market-researcher`).
- `plugins/empire-*/skills/<skill-name>/SKILL.md` — one dir per skill. Skill name in frontmatter MUST match dir name.
- `plugins/empire-*/README.md` — one per plugin. Plugin-specific docs (skills list, triggers, source links). Root `README.md` is the project intro and links to these.
- `docs/superpowers/{specs,plans}/` — gitignored. Local-only design notes. Never commit.

## Skill authoring rules

- Frontmatter required: `name`, `description`. Optional: `model`, `allowed-tools`, `argument-hint`, `disable-model-invocation`.
- `description` MUST list trigger phrases verbatim — Claude auto-route uses them.
- Reference bundled scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/<file>.sh`. Never hardcode repo paths.
- Users invoke skills as `/<plugin>:<skill-name>` once installed. Plugin namespaces: `empire-git`, `empire-dev`, `empire-research`, `empire-product`. The meta `empire` plugin contributes no skills.
- After editing a SKILL.md, also update the matching section in the plugin's `README.md` (`plugins/<plugin>/README.md`) if triggers, args, or behavior changed. Update root `README.md` only if the one-line plugin description in the plugins table needs to change.

## Adding a new skill

1. Pick the right plugin (`empire-git`, `empire-dev`, `empire-research`, or `empire-product`). Create a new plugin only if the skill clearly fits no existing namespace.
2. Create `plugins/<plugin>/skills/<name>/SKILL.md` with frontmatter + body. Frontmatter `name` MUST match dir name.
3. Add a section to the plugin's `README.md` (`plugins/<plugin>/README.md`) under `## Skills`, mirroring existing entries (description, triggers, source link). If the plugin's one-line summary in the root `README.md` table is now out of date, update it too.
4. If shipping a script, drop it in `plugins/<plugin>/scripts/` and `chmod +x`.
5. Bump the version in `plugins/<plugin>/.claude-plugin/plugin.json`. If the change is user-visible across multiple sub-plugins, also bump `plugins/empire-meta/.claude-plugin/plugin.json`.
6. Test by installing the marketplace locally in Claude Code: `/plugin marketplace add <local-path-or-fork>` then `/plugin install <plugin>@empire` (or `empire@empire` for the bundle).

## Conventions

- Kebab-case for skill dirs and script filenames.
- Conventional Commits with optional scope. Use the plugin name as scope: `empire-git`, `empire-dev`, `empire-research`, `empire-product`, `empire-meta`, `empire-rules`. Use `marketplace` for marketplace-level changes. Use `!` for breaking marketplace/manifest changes.
- Skill prose = imperative mood, MUST/SHOULD/MAY, fragments. See `plugins/empire-dev/skills/review/SKILL.md` for section-tag style.
- Scripts use `set -euo pipefail`, color-coded `info/warn/die/success` helpers (pattern in `worktree-setup.sh`).

## Formatting and linting

- All formatting + security hooks orchestrated by `pre-commit` (config in `.pre-commit-config.yaml`).
- Tools: `prettier` (markdown/yaml/json), `shfmt` (shell), `shellcheck` (shell security), `actionlint` (GH Actions), `gitleaks` (secrets).
- One-time dev setup: `brew install pre-commit && pre-commit install`.
- CI runs identical checks via `.github/workflows/validate.yml`.
- Never bypass with `--no-verify`. If a hook fails, fix the underlying issue.

## What this repo is NOT

- Not a Node/Python/Go project. No `package.json`, no `pyproject.toml`. Don't add a build system unless asked.
- Not a backend. Skills run inside Claude Code on the user's machine. Assume zero server-side state.

<!-- empire:dev:start -->

# empire-dev

Skills installed under the `empire-dev` Claude Code plugin. Findings stay local — never posted to GitHub or external services.

## Skill: `review`

- For non-trivial diffs or PRs, prefer `/empire-dev:review` over single-pass review
- Skill dispatches parallel specialist subagents (architecture, security, performance, tests, generalist) and consolidates findings
- For follow-up passes after addressing comments, say "re-review" or "another pass" — the skill reuses the same roster
- Findings stay local in chat; never post to GitHub

## Bundled subagents

The plugin ships eleven fallback subagents that the `review` skill auto-discovers at dispatch time:

- Code review: `code-reviewer`, `debugger`, `test-automator`, `security-auditor`, `architect-review`, `performance-engineer`
- Paradigm specialists: `functional-programming-expert`, `concurrency-reviewer`, `type-system-expert`
- Domain experts: `blockchain-developer`, `ai-engineer`

If your environment has more specialized subagents installed, the skill will pick the best match available — no configuration needed.

<!-- empire:dev:end -->

<!-- empire:git:start -->

## Empire git workflow

Skills installed under the `empire-git` Claude Code plugin.

### Worktrees

Run multiple branches of the same repo in parallel, each in its own isolated git worktree. Per-branch directory, dependencies, ports, and `.env` files.

- MUST use `/empire-git:worktree-*` skills — never raw `git worktree add|remove|prune`
- `/empire-git:worktree-open <branch | task description> [--base <b>]` — create or reopen a worktree (env, deps, ports handled)
- `/empire-git:worktree-list [--stale]` — list active worktrees with sync state and staleness
- `/empire-git:worktree-merge <branch> --into <target> [--no-close]` — local merge between worktree branches
- `/empire-git:worktree-close [branch] [--push] [--force]` — finish work; remove worktree, optionally delete branch
- `/empire-git:worktree-cleanup [--dry-run]` — batch prune stale worktrees, missing dirs, orphaned branches, branches whose remote PR merged
- `/empire-git:worktree-help [topic]` — FAQ: ports, env files, VSCode, merge strategies

Conventions:

- Branch name = source of truth — same branch always reopens the same path (deterministic hash)
- Each worktree gets a deterministic port offset (0–99 from path hash) — no port collisions across parallel agents
- `.env*` files are copied (not symlinked) per worktree; symlinked envs are skipped
- Subagents doing isolated work MUST run inside a `/empire-git:worktree-open` worktree

### Pull requests

- MUST invoke `/empire-git:pr-description` before any `gh pr create --body*` or `gh pr edit --body*` and use its output verbatim
- The skill preserves user-added content outside `<!-- pr-description:start -->` / `<!-- pr-description:end -->` markers when updating an existing body
- Title format: Conventional Commits, lowercase, no period, ≤ 72 chars
<!-- empire:git:end -->

<!-- empire:product:start -->

## Empire product communication

Skills installed under the `empire-product` Claude Code plugin. Findings stay local — never posted to Slack, GitHub, Jira, or external systems.

### Pitches — `pitch`

- For elevator pitches, project intros, or personal "tell me about yourself" prep, use `/empire-product:pitch`
- The skill reads `package.json`, README, and recent commits for repo pitches; produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference)
- Do not write pitch copy from scratch when the skill is available — output drift erodes brand voice

Conventions:

- Audience MUST be specified or asked: developer, investor, conference, generic
- Output length matches request: one-liner / 30-second / full intro

### Idea validation — `vet`

- For pressure-testing a product idea before building, use `/empire-product:vet` instead of ad-hoc validation
- Skill operates in anti-sycophancy mode: default skepticism, fatal-flaw hypothesis, evidence-based critique
- Output: structured demand signals, competitor teardown, fatal flaws, earned strengths, risks, recommendation (PROCEED / PIVOT / KILL)
- Confidence-tagged: every claim marked `[Confirmed]`, `[Estimated]`, or `[Inferred]`
- Skill never implements — recommendation only

### Competitor mapping — `recon`

- For mapping competitive landscape (pricing, features, positioning) across competitors, use `/empire-product:recon`
- Skill dispatches one agent per competitor in parallel; consolidates a side-by-side matrix with confidence tags and as-of dates
- Ethical scope: public information only — never social engineering, credential stuffing, or unauthorized access
- Output includes gaps, positioning angle, and prioritized action items
- Skill never implements — recommendation only

### Bundled subagents

The plugin ships three fallback subagents that the skills auto-discover at dispatch time:

- `project-idea-validator` — anchor for `vet`
- `competitive-analyst` — anchor for `recon`
- `market-researcher` — market sizing, audience research, trend analysis

If your environment has more specialized subagents installed, the skills will pick the best match available — no configuration needed.

<!-- empire:product:end -->

<!-- empire:research:start -->

# empire-research

Skills installed under the `empire-research` Claude Code plugin. Findings stay local — never posted to Slack, GitHub, Jira, or external systems.

## Skill: `explore`

- For open-ended approach exploration ("what could we do for X?"), use `/empire-research:explore` instead of ad-hoc one-pass investigation
- Skill performs a shallow scan first to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros / cons and a recommended direction
- Skill never implements — recommendation only. Wait for user to choose the direction before any edits.

## Skill: `compare`

- For closed comparison of a known set of options head-to-head ("A vs B vs C"), use `/empire-research:compare`
- Skill skips the shallow scan because options are already known; dispatches one agent per option in parallel; consolidates a side-by-side matrix with confidence-tagged scoring
- Output marks each cell as `[Confirmed]`, `[Estimated]`, or `[Inferred]` so users know what's evidence vs. reasoning

## Bundled subagent

The plugin ships one fallback subagent that both skills auto-discover at dispatch time:

- `research-analyst` — multi-source research synthesis and reporting

If your environment has more specialized research subagents installed (e.g. competitive-analyst, market-researcher, language-specific experts), the skills will pick the best match available — no configuration needed.

<!-- empire:research:end -->
