---
name: sync-rules
description: Reconcile per-plugin skill-routing snippets from installed empire-* plugins into the project's AGENTS.md (or CLAUDE.md). Idempotent. Use when the user asks to "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules", or after installing or updating an empire-* plugin and wanting its routing block written into the project file. Invoke from a git working tree.
argument-hint: "[plugin]"
allowed-tools: Bash
---

# sync-rules

Reconcile installed empire-\* plugin snippets into the project's `AGENTS.md`.

## Required output structure

Every reply for this skill MUST follow these three blocks, in order:

1. **Summary line** — copy the `==>` summary lines from the script verbatim.
2. **Diff** — embed the script's unified-diff output inside a fenced ` ```diff ` block. Do not summarize, truncate, or paraphrase. If the script reported `Already in sync.`, write `_no changes_` instead and stop here.
3. **Confirmation prompt** — on its own line, write exactly: `Apply these changes? [y/N]`

Stop after the confirmation prompt. Wait for the user's reply.

## Two-call flow

1. **Preview**. Run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-rules.sh "$ARGUMENTS"`. Capture the entire stdout. Render it per the structure above.
2. **Apply**. Only after the user replies `y`/`yes`, run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-rules.sh "$ARGUMENTS" --apply`. Embed the full stdout in a fenced code block.

Never invoke `--apply` before showing the preview to the user.

## Argument

- `[plugin]`: optional plugin name (e.g. `empire-git`). When set, only that plugin's marker block is touched; other empire blocks are left alone.

## Rules for the model

- Render the script's full stdout in the chat reply. Hidden tool output does NOT satisfy the "show the diff" requirement — the diff must appear in your reply text.
- Do not invent flags or pre-flight steps not in the script.
- If the script exits non-zero, embed the error message in a fenced code block and stop. Do not retry.
- The script enforces "must be in a git working tree". If it errors out for that reason, relay the message — do not attempt to `cd` elsewhere.
