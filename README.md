# empire

Claude Code skills for the solo founder commanding a one-person empire.

You're the CEO. The skills are your staff — review your PRs, research approaches, draft pitches, write release notes. Solo on paper. Crewed in practice.

## Install

Add the marketplace once:

```sh
/plugin marketplace add marcoskichel/empire
```

Then install everything in one shot via the `empire` bundle:

```sh
/plugin install empire@empire
```

`empire` is a meta plugin that pulls in three sub-plugins:

| Plugin           | Skills                                                                                                                      | Install individually                    |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| `empire-git`     | `worktree-open`, `worktree-close`, `worktree-merge`, `worktree-list`, `worktree-cleanup`, `worktree-help`, `pr-description` | `/plugin install empire-git@empire`     |
| `empire-team`    | `review`, `research`                                                                                                        | `/plugin install empire-team@empire`    |
| `empire-product` | `pitch`                                                                                                                     | `/plugin install empire-product@empire` |

Skills are namespaced by plugin. Invoke as `/empire-git:worktree-open`, `/empire-team:review`, `/empire-product:pitch`, etc. Claude also auto-routes based on the trigger phrases listed in each SKILL.md.

## Skills

### empire-team

#### `review`

Spawn parallel specialist subagents (architecture, security, performance, tests, generalist) to review a diff or PR, then consolidate findings into a single deduplicated report. Findings stay local — never posted to GitHub.

Triggers: "team review", "have specialists review", "review my changes", "re-review", "another pass", "ask the team", "specialist review".

Source: [`plugins/empire-team/skills/review/SKILL.md`](plugins/empire-team/skills/review/SKILL.md)

#### `research`

Spawn parallel research subagents to evaluate approaches to a problem. First does a shallow scan to enumerate 3–5 candidate approaches, then dispatches one research agent per approach the user selects, then consolidates a comparison report with pros/cons and a recommended direction. Findings stay local — never posted externally.

Triggers: "team research", "research approaches", "explore options", "investigate approaches", "compare approaches", "what are the options", "options analysis".

Source: [`plugins/empire-team/skills/research/SKILL.md`](plugins/empire-team/skills/research/SKILL.md)

### empire-product

#### `pitch`

Generate elevator pitches for repos or people. Reads project context (`package.json`, README, recent commits) and produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference).

Triggers: "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", "tell me about yourself".

Source: [`plugins/empire-product/skills/pitch/SKILL.md`](plugins/empire-product/skills/pitch/SKILL.md)

### empire-git

#### `pr-description`

Canonical PR description template. Senior-reviewer voice, ≤200 words, sections for Why / What changed / Risk / Test plan, idempotency markers (`<!-- pr-description:start/end -->`) to preserve user-added content (screenshots, `Fixes #N`, task lists) when updating. Pure content template — caller decides where to write (stdout, `gh pr create --body-file -`, `gh pr edit --body-file -`).

Triggers: "write PR description", "draft PR body", "update PR description", "pr summary", "summarize this branch for review".

To make it impossible for the agent to bypass, add this one-line rule to your project or user CLAUDE.md:

```
- Before any `gh pr create --body*` or `gh pr edit --body*`, MUST invoke the `pr-description` skill and use its output verbatim.
```

Source: [`plugins/empire-git/skills/pr-description/SKILL.md`](plugins/empire-git/skills/pr-description/SKILL.md)

#### `worktree-*` (open / close / merge / list / cleanup / help)

Run multiple branches of the same repo in parallel, each in its own isolated git worktree. Per-branch directory, dependencies, ports, and `.env` files — so you (or a Claude agent) can spin up a parallel task without disrupting your main checkout. Lifecycle skills handle creation, merging, listing, batch cleanup, and teardown.

Zero per-repo setup: the bundled `worktree-setup.sh` auto-detects the package manager from lockfiles (`pnpm`, `npm`, `yarn`, `bun`, `uv`, `poetry`, `pipenv`, `bundler`, `cargo`, `go` modules) and writes `.claude/worktrees` to `.git/info/exclude` so the host repo's tracked `.gitignore` stays untouched.

| Command                                                            | Purpose                                                  |
| ------------------------------------------------------------------ | -------------------------------------------------------- |
| `/empire-git:worktree-open <branch \| task> [--base <b>]`          | Create or reopen a worktree (env, deps, ports handled)   |
| `/empire-git:worktree-list [--stale]`                              | List active worktrees with branch, sync state, staleness |
| `/empire-git:worktree-merge <branch> --into <target> [--no-close]` | Local `git merge` of one branch into another             |
| `/empire-git:worktree-close [branch] [--push] [--force]`           | Push, remove the worktree, optionally delete the branch  |
| `/empire-git:worktree-cleanup [--dry-run]`                         | Batch cleanup of stale worktrees and orphaned branches   |
| `/empire-git:worktree-help [question]`                             | FAQ about worktrees, ports, env files, VSCode setup      |

Triggers: "open a worktree", "work on X separately", "in parallel", "spin up a branch", "list worktrees", "what worktrees do I have", "close this worktree", "merge worktree", "clean up worktrees", "stale worktrees".

Inspired by [`@thinkvelta/claude-worktree-tools`](https://github.com/ThinkVelta/claude-worktree-tools) (MIT) — repackaged as a Claude Code plugin with auto-detection so per-repo `npx` install and `/wt-adopt` are no longer required.

Source: [`plugins/empire-git/skills/worktree-open/SKILL.md`](plugins/empire-git/skills/worktree-open/SKILL.md), [`plugins/empire-git/scripts/worktree-setup.sh`](plugins/empire-git/scripts/worktree-setup.sh)

## Contributing

Format and lint hooks run via [`pre-commit`](https://pre-commit.com). One-time setup:

```sh
brew install pre-commit
pre-commit install
```

After that, every `git commit` runs:

- `prettier` — markdown / YAML / JSON formatting
- `shfmt` — shell script formatting (`-i 2 -ci -bn`)
- `shellcheck` — shell script linting / security
- `actionlint` — GitHub Actions workflow linting (catches `${{ github.event.* }}` injection)
- `gitleaks` — secret scanning
- end-of-file / trailing-whitespace / merge-conflict / JSON / YAML basics

CI mirrors the same checks on every push and PR via `.github/workflows/validate.yml`.

## License

MIT
