# empire-git

Git workflow skills: parallel worktree lifecycle and PR description templating.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-git@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Skills

### `pr-description`

Canonical PR description template. Senior-reviewer voice, ≤200 words, sections for Why / What changed / Risk / Test plan, idempotency markers (`<!-- pr-description:start/end -->`) to preserve user-added content (screenshots, `Fixes #N`, task lists) when updating. Pure content template — caller decides where to write (stdout, `gh pr create --body-file -`, `gh pr edit --body-file -`).

Triggers: "PR description", "PR body", "pull request description", "PR summary", "PR template", "GitHub PR body", "draft a PR", "write the PR", "summarize this branch for review", "regenerate PR body".

To make it impossible for the agent to bypass, add this one-line rule to your project or user CLAUDE.md:

```
- Before any `gh pr create --body*` or `gh pr edit --body*`, MUST invoke the `pr-description` skill and use its output verbatim.
```

Source: [`skills/pr-description/SKILL.md`](skills/pr-description/SKILL.md)

### `worktree-*` (open / close / merge / list / cleanup / help)

Run multiple branches of the same repo in parallel, each in its own isolated git worktree. Per-branch directory, dependencies, ports, and `.env` files — so you (or a Claude agent) can spin up a parallel task without disrupting your main checkout. Lifecycle skills handle creation, merging, listing, batch cleanup, and teardown.

Zero per-repo setup: the bundled `worktree-setup.sh` auto-detects the package manager from lockfiles (`pnpm`, `npm`, `yarn`, `bun`, `uv`, `poetry`, `pipenv`, `bundler`, `cargo`, `go` modules) and writes `.claude/worktrees` to `.git/info/exclude` so the host repo's tracked `.gitignore` stays untouched.

| Command                                                                   | Purpose                                                                                                                     |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `/empire-git:worktree-open <branch \| task> [--base <b>]`                 | Create or reopen a worktree (env, deps, ports handled)                                                                      |
| `/empire-git:worktree-list [--stale]`                                     | List active worktrees with branch, sync state, staleness                                                                    |
| `/empire-git:worktree-merge <branch> --into <target> [--no-close] [--ff]` | Local `git merge` of one branch into another                                                                                |
| `/empire-git:worktree-close [branch] [--push] [--discard] [--force]`      | Finish ONE worktree: push, remove, optionally delete branch (`--discard` skips dirty-check; `--force` skips cleanup-prompt) |
| `/empire-git:worktree-cleanup [--dry-run] [--days N]`                     | Batch cleanup across MULTIPLE stale worktrees and orphaned branches                                                         |
| `/empire-git:worktree-help [question]`                                    | FAQ about worktrees, ports, env files, VSCode setup                                                                         |

Triggers: "open a worktree", "work on X separately", "in parallel", "spin up a branch", "list worktrees", "what worktrees do I have", "close this worktree", "merge worktree", "fold sub-branches", "clean up worktrees", "stale worktrees", "orphan branches", "purge stale worktrees".

Source: [`skills/worktree-open/SKILL.md`](skills/worktree-open/SKILL.md), [`scripts/worktree-setup.sh`](scripts/worktree-setup.sh)
