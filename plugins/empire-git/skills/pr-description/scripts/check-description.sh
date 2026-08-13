#!/usr/bin/env bash
# shellcheck disable=SC2317  # functions are invoked indirectly via $fn
# Classify a PR description as TLDR-quality or needing a rewrite.
# Usage: check-description.sh <body-file>
# Prints PASS, or REWRITE followed by reasons. Exit 0 = PASS, 1 = REWRITE, 2 = no classifier available (skip the gate).
set -euo pipefail

BODY_FILE="${1:?usage: check-description.sh <body-file>}"
TIMEOUT_SECS="${PR_DESC_CHECK_TIMEOUT:-20}"

PROMPT='You are a strict PR description reviewer. Judge ONLY the text after the --- line.
A good description is TLDR-quality: direct, concise, no trivia. Reject when it has any of:
- filler openers ("This PR", "We", "I am"), marketing tone, or emoji
- trivia a reviewer does not need (mechanical renames, "updated tests", CI steps, restating the diff)
- prose a reviewer cannot grasp in one pass (long sentences, buried point)
- padding sections or bullets that add no information
Reply with exactly PASS on the first line if acceptable.
Otherwise reply REWRITE on the first line, then one short reason per line (max 4).'

INPUT="$PROMPT

---
$(cat "$BODY_FILE")"

# Portable timeout: coreutils timeout if present, else perl alarm.
run_with_timeout() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECS" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT_SECS" "$@"
  else
    perl -e 'alarm shift; exec @ARGV' "$TIMEOUT_SECS" "$@"
  fi
}

valid() { case "$1" in PASS* | REWRITE*) return 0 ;; *) return 1 ;; esac }

try_claude() {
  command -v claude >/dev/null 2>&1 || return 1
  local out
  # Plain first (API-key users), then without ANTHROPIC_API_KEY (stale key shadowing claude.ai login).
  out=$(printf '%s' "$INPUT" | run_with_timeout claude -p --model haiku 2>/dev/null) && valid "$out" \
    || out=$(printf '%s' "$INPUT" | run_with_timeout env -u ANTHROPIC_API_KEY claude -p --model haiku 2>/dev/null) \
    || return 1
  printf '%s' "$out"
}

try_codex() {
  command -v codex >/dev/null 2>&1 || return 1
  run_with_timeout codex exec --model gpt-5-nano "$INPUT" </dev/null 2>/dev/null
}

try_pi() {
  command -v pi >/dev/null 2>&1 || return 1
  run_with_timeout pi -p --model "haiku" "$INPUT" </dev/null 2>/dev/null
}

# Prefer the CLI of the harness running this skill — it is the one guaranteed authenticated.
if [ -n "${PI_CODING_AGENT:-}" ]; then
  ORDER="try_pi try_claude try_codex"
elif [ -n "${CODEX_HOME:-}${CODEX_SANDBOX:-}" ]; then
  ORDER="try_codex try_claude try_pi"
else
  ORDER="try_claude try_codex try_pi"
fi

for fn in $ORDER; do
  RESULT=$("$fn") || continue
  case "$RESULT" in
    PASS*)
      echo "$RESULT"
      exit 0
      ;;
    REWRITE*)
      echo "$RESULT"
      exit 1
      ;;
  esac
  # Anything else (empty, "Execution error", prose) → CLI unusable, try the next one.
done

echo "SKIP: no working classifier CLI (pi/claude/codex) within ${TIMEOUT_SECS}s each" >&2
exit 2
