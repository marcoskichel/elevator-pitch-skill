---
name: sync-rules
description: Reconcile per-plugin skill-routing snippets from installed empire-* plugins into the project's AGENTS.md (or CLAUDE.md). Idempotent. Use when the user asks to "sync empire rules", "update AGENTS.md from empire", "apply empire routing rules", "install empire skill rules", or after installing or updating an empire-* plugin and wanting its routing block written into the project file. Invoke from a git working tree.
argument-hint: "[plugin]"
allowed-tools: Bash
---

# sync-rules

Reconcile installed empire-\* plugin snippets into the project's `AGENTS.md`.

## Two-call flow

1. **Preview**. Run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-rules.sh "$ARGUMENTS"`. Print the script's stdout verbatim — it contains the planned add / update / remove summary plus a unified diff.
2. **Confirm**. If the summary shows no changes (`Already in sync.`), stop. Otherwise ask the user: `Apply these changes? [y/N]`. Wait for their reply.
3. **Apply**. On confirmation only, run `${CLAUDE_PLUGIN_ROOT}/scripts/sync-rules.sh "$ARGUMENTS" --apply`. Print the script's stdout verbatim. On any other answer, do not run the apply step.

Never invoke `--apply` before showing the preview to the user.

## Argument

- `[plugin]`: optional plugin name (e.g. `empire-git`). When set, only that plugin's marker block is touched; other empire blocks are left alone.

## Rules for the model

- Pass the script's output through verbatim. Do not summarize or paraphrase.
- Do not invent flags or pre-flight steps not in the script.
- If the script exits non-zero, surface its error message exactly. Do not retry.
- The script enforces "must be in a git working tree". If it errors out for that reason, relay the message — do not attempt to `cd` elsewhere.
