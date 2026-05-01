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
