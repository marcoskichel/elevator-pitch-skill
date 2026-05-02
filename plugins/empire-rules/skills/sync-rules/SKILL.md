---
name: sync-rules
description: Reconcile per-plugin skill-routing snippets from installed empire-* plugins into a target rules file (project AGENTS.md or user-global ~/.claude/CLAUDE.md). Idempotent. Use when the user asks to "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules", or after installing or updating an empire-* plugin and wanting its routing block written to the rules file.
argument-hint: "[plugin] [--scope user|project|both]"
allowed-tools: Bash
---

# sync-rules

Reconcile installed empire-\* plugin snippets into a rules file. Default target is the user-global file (`~/.claude/CLAUDE.md`) — that matches the default `claude plugin install` scope so the routing rules apply wherever the skills do. Project scope (`./AGENTS.md`) is for teammates who share rules via version control.

## Required output structure

Every reply for this skill MUST follow these blocks, in order:

1. **Summary lines** — copy the `==>` summary lines from the script verbatim (Scope, Target, Add/Update/Remove/Noop). With `--scope both`, two summary blocks appear.
2. **Diff** — embed the script's unified-diff output inside a fenced ` ```diff ` block. Do not summarize, truncate, or paraphrase. If a scope reports `Already in sync.`, write `_no changes_` for that scope.
3. **Confirmation prompt** — on its own line, write exactly: `Apply these changes? [y/N]`

Stop after the confirmation prompt. Wait for the user's reply.

## Flow

1. **Preview** — run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-rules.sh "$ARGUMENTS"`.

   - **Exit 0**: render the output per the structure above. Remember the `Scope:` line(s) printed — you will reuse them on apply.
   - **Exit 3** (no scope determined and no existing markers): the script printed instructions on stdout / stderr. Do NOT show those instructions. Instead ask the user this exact prompt and stop, waiting for the reply:

     > Where should empire routing rules be written?
     >
     > - **`u` — user scope** (`~/.claude/CLAUDE.md`). Recommended. Rules apply in every repo, matching the default plugin install scope.
     > - **`p` — project scope** (`./AGENTS.md`). Per-repo. Teammates share rules via version control.
     > - **`b` — both**.
     >
     > Pick scope: [U/p/b]

     On reply, re-run the script with the chosen `--scope <user|project|both>` and the original `$ARGUMENTS`. Render that output per the structure.

   - Other non-zero exit: embed the error in a fenced code block and stop. Do not retry.

2. **Apply** — only after the user replies `y`/`yes` to the confirmation prompt, run the script again with the same arguments **plus** `--apply`. Embed the full stdout in a fenced code block. Do not invoke `--apply` before the user has confirmed.

## Argument

- `[plugin]`: optional plugin name (e.g. `empire-git`). Restricts reconciliation to that plugin's marker block.
- `--scope user|project|both`: optional. When passed by the user, skip the auto-detect prompt; otherwise the script auto-detects from existing markers and prompts only when neither file has them.

## Rules for the model

- Render the script's full stdout in the chat reply. Hidden tool output does NOT satisfy the "show the diff" requirement.
- When the script exits 3, do NOT pass `--scope` automatically. Ask the user; default to user scope only after they pick.
- Do not invent flags. Only `--apply` and `--scope <user|project|both>` are valid.
- If the script exits 1 (precondition failure) or any other unexpected non-zero, surface its stderr exactly and stop.
- For `--scope both`, the script writes two files; both diffs appear in the preview.
