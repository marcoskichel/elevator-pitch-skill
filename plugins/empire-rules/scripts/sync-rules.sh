#!/usr/bin/env bash
# sync-rules.sh — Reconcile per-plugin skill-routing snippets from installed
# empire-* plugins into the project's AGENTS.md (or CLAUDE.md).
# Part of the empire-rules Claude Code plugin.
#
# Usage:
#   sync-rules.sh [plugin] [--apply]
#
# Default (preview): prints summary + unified diff, exits 0 if changes pending.
# With --apply:      writes target file atomically, prints summary.
#
# Exit codes:
#   0  success (preview shown, or apply succeeded, or already in sync)
#   1  precondition failure (not in git repo, missing tools, etc.)
#   2  unexpected runtime error

set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$1" >&2
  exit 1
}

info() {
  printf '\033[1;34m==>\033[0m %s\n' "$1"
}

warn() {
  printf '\033[1;33mWARN:\033[0m %s\n' "$1" >&2
}

success() {
  printf '\033[1;32m==>\033[0m %s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

resolve_path() {
  local p="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$p" 2>/dev/null || printf '%s' "$p"
  else
    perl -MCwd -le 'print Cwd::abs_path($ARGV[0])' "$p" 2>/dev/null || printf '%s' "$p"
  fi
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

require_cmd jq
require_cmd diff
require_cmd awk
require_cmd claude

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "Not inside a git working tree. Run from a project repo."

cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

FILTER_PLUGIN=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      cat <<EOF
sync-rules.sh — sync empire-* skill routing snippets into project AGENTS.md.

Usage:
  sync-rules.sh [plugin] [--apply]

  plugin   Optional. Plugin name (e.g. empire-git). When set, only that
           plugin's marker block is touched; other empire blocks are left.
  --apply  Write the reconciled file. Default mode prints a preview only.
EOF
      exit 0
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      [[ -n "$FILTER_PLUGIN" ]] && die "Unexpected argument: $1 (plugin already set to '$FILTER_PLUGIN')"
      FILTER_PLUGIN="$1"
      shift
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Target file resolution
# ---------------------------------------------------------------------------

if [[ -e "$REPO_ROOT/AGENTS.md" ]]; then
  TARGET="$REPO_ROOT/AGENTS.md"
elif [[ -e "$REPO_ROOT/CLAUDE.md" ]]; then
  TARGET="$REPO_ROOT/CLAUDE.md"
else
  TARGET="$REPO_ROOT/AGENTS.md"
fi

if [[ -L "$TARGET" ]]; then
  RESOLVED="$(resolve_path "$TARGET")"
  case "$RESOLVED" in
    "$REPO_ROOT"/*) ;;
    *) die "Target file resolves outside the repo: $RESOLVED" ;;
  esac
fi

# ---------------------------------------------------------------------------
# Plugin enumeration
# ---------------------------------------------------------------------------

PLUGINS_JSON="$(claude plugin list --json 2>/dev/null)" \
  || die "Failed to run 'claude plugin list --json'"

PLUGINS_TSV="$(printf '%s' "$PLUGINS_JSON" | jq -r '
  .[]
  | select(.enabled)
  | (.id | split("@")[0]) as $name
  | select($name | startswith("empire-"))
  | select($name != "empire-rules")
  | "\($name)\t\(.installPath)"
' | sort)"

if [[ -n "$FILTER_PLUGIN" && -n "$PLUGINS_TSV" ]]; then
  PLUGINS_TSV="$(printf '%s\n' "$PLUGINS_TSV" | awk -v p="$FILTER_PLUGIN" -F'\t' '$1 == p')"
fi

# ---------------------------------------------------------------------------
# Snippet collection
# ---------------------------------------------------------------------------

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

INSTALLED_DIR="$TMPDIR_WORK/installed"
EXISTING_DIR="$TMPDIR_WORK/existing"
mkdir -p "$INSTALLED_DIR" "$EXISTING_DIR"

if [[ -n "$PLUGINS_TSV" ]]; then
  while IFS=$'\t' read -r plugin_name plugin_path; do
    [[ -z "$plugin_name" ]] && continue
    snippet_path="$plugin_path/rules/AGENTS.md"
    if [[ ! -f "$snippet_path" ]]; then
      warn "$plugin_name: no rules/AGENTS.md at $snippet_path (skipping)"
      continue
    fi
    cp "$snippet_path" "$INSTALLED_DIR/$plugin_name"
  done <<<"$PLUGINS_TSV"
fi

# ---------------------------------------------------------------------------
# Existing-block extraction
# ---------------------------------------------------------------------------

if [[ -f "$TARGET" ]]; then
  awk -v outdir="$EXISTING_DIR" '
    /^<!-- empire:[^:[:space:]]+:start -->$/ {
      short = $0
      sub(/^<!-- empire:/, "", short)
      sub(/:start -->$/, "", short)
      name = "empire-" short
      out = outdir "/" name
      printf "" > out
      in_block = 1
      next
    }
    /^<!-- empire:[^:[:space:]]+:end -->$/ {
      in_block = 0
      out = ""
      next
    }
    in_block { print >> out }
  ' "$TARGET"
fi

# ---------------------------------------------------------------------------
# Reconciliation
# ---------------------------------------------------------------------------

list_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -mindepth 1 -type f -exec basename {} \; 2>/dev/null | sort
}

scope_names() {
  {
    list_dir "$INSTALLED_DIR"
    list_dir "$EXISTING_DIR"
  } | sort -u
}

ADDS=()
UPDATES=()
REMOVES=()
NOOPS=()

while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  if [[ -n "$FILTER_PLUGIN" && "$name" != "$FILTER_PLUGIN" ]]; then
    continue
  fi
  inst="$INSTALLED_DIR/$name"
  exst="$EXISTING_DIR/$name"
  if [[ -f "$inst" && ! -f "$exst" ]]; then
    ADDS+=("$name")
  elif [[ -f "$inst" && -f "$exst" ]]; then
    if cmp -s "$inst" "$exst"; then
      NOOPS+=("$name")
    else
      UPDATES+=("$name")
    fi
  elif [[ ! -f "$inst" && -f "$exst" ]]; then
    REMOVES+=("$name")
  fi
done < <(scope_names)

OPS_COUNT=$((${#ADDS[@]} + ${#UPDATES[@]} + ${#REMOVES[@]}))

# ---------------------------------------------------------------------------
# Render new target file
# ---------------------------------------------------------------------------

format_block() {
  local name="$1" content_file="$2"
  local short="${name#empire-}"
  printf '<!-- empire:%s:start -->\n' "$short"
  if [[ -s "$content_file" ]]; then
    awk '{ lines[NR] = $0; total = NR }
      END {
        last = total
        while (last > 0 && lines[last] == "") last--
        for (i = 1; i <= last; i++) print lines[i]
      }' "$content_file"
  fi
  printf '<!-- empire:%s:end -->\n' "$short"
}

NEW_FILE="$TMPDIR_WORK/new-target.md"
STRIPPED="$TMPDIR_WORK/stripped.md"
: >"$STRIPPED"

if [[ -f "$TARGET" ]]; then
  awk '
    /^<!-- empire:[^:[:space:]]+:start -->$/ { skip = 1; next }
    /^<!-- empire:[^:[:space:]]+:end -->$/ { skip = 0; next }
    skip { next }
    { print }
  ' "$TARGET" >"$STRIPPED"
  awk 'NR==FNR { lines[NR] = $0; total = NR; next } END {
    last = total
    while (last > 0 && lines[last] == "") last--
    for (i = 1; i <= last; i++) print lines[i]
  }' "$STRIPPED" "$STRIPPED" >"$STRIPPED.trim"
  mv "$STRIPPED.trim" "$STRIPPED"
fi

FINAL_NAMES=()
if [[ -n "$FILTER_PLUGIN" ]]; then
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ "$name" == "$FILTER_PLUGIN" ]]; then
      [[ -f "$INSTALLED_DIR/$name" ]] && FINAL_NAMES+=("$name")
    else
      [[ -f "$EXISTING_DIR/$name" ]] && FINAL_NAMES+=("$name")
    fi
  done < <(scope_names)
else
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    [[ -f "$INSTALLED_DIR/$name" ]] && FINAL_NAMES+=("$name")
  done < <(scope_names)
fi

cp "$STRIPPED" "$NEW_FILE"
if [[ ${#FINAL_NAMES[@]} -gt 0 ]]; then
  if [[ -s "$NEW_FILE" ]]; then
    printf '\n' >>"$NEW_FILE"
  fi
  first=1
  for name in "${FINAL_NAMES[@]}"; do
    if [[ "$first" -eq 0 ]]; then
      printf '\n' >>"$NEW_FILE"
    fi
    first=0
    if [[ -f "$INSTALLED_DIR/$name" ]]; then
      format_block "$name" "$INSTALLED_DIR/$name" >>"$NEW_FILE"
    elif [[ -f "$EXISTING_DIR/$name" ]]; then
      format_block "$name" "$EXISTING_DIR/$name" >>"$NEW_FILE"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Summary output
# ---------------------------------------------------------------------------

print_summary() {
  info "Target: $TARGET"
  if [[ -n "$FILTER_PLUGIN" ]]; then
    info "Filter: $FILTER_PLUGIN"
  fi
  if [[ ${#ADDS[@]} -gt 0 ]]; then
    info "Add:    ${ADDS[*]}"
  fi
  if [[ ${#UPDATES[@]} -gt 0 ]]; then
    info "Update: ${UPDATES[*]}"
  fi
  if [[ ${#REMOVES[@]} -gt 0 ]]; then
    info "Remove: ${REMOVES[*]}"
  fi
  if [[ ${#NOOPS[@]} -gt 0 ]]; then
    info "Noop:   ${NOOPS[*]}"
  fi
}

if [[ "$OPS_COUNT" -eq 0 ]]; then
  print_summary
  success "Already in sync."
  exit 0
fi

print_summary
echo

REL_TARGET="${TARGET#"$REPO_ROOT"/}"
if [[ -f "$TARGET" ]]; then
  diff -u --label "a/$REL_TARGET" --label "b/$REL_TARGET" "$TARGET" "$NEW_FILE" || true
else
  diff -u --label /dev/null --label "b/$REL_TARGET" /dev/null "$NEW_FILE" || true
fi

if [[ "$APPLY" -eq 0 ]]; then
  echo
  info "Preview only. Re-run with --apply to write changes."
  exit 0
fi

# ---------------------------------------------------------------------------
# Atomic write
# ---------------------------------------------------------------------------

WRITE_DEST="$TARGET"
if [[ -L "$WRITE_DEST" ]]; then
  WRITE_DEST="$(resolve_path "$WRITE_DEST")"
fi

mkdir -p "$(dirname "$WRITE_DEST")"
TMP_OUT="$(mktemp "$WRITE_DEST.empire-XXXXXX")"
cp "$NEW_FILE" "$TMP_OUT"
mv "$TMP_OUT" "$WRITE_DEST"

echo
success "Wrote $WRITE_DEST (${#ADDS[@]} added, ${#UPDATES[@]} updated, ${#REMOVES[@]} removed)"
