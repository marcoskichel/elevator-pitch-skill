#!/usr/bin/env bash
# sync-rules.sh — Reconcile per-plugin skill-routing snippets from installed
# empire-* plugins into a target rules file (project AGENTS.md or user-global
# ~/.claude/CLAUDE.md).
# Part of the empire-rules Claude Code plugin.
#
# Usage:
#   sync-rules.sh [plugin] [--scope user|project|both]
#
# Always preview-only: prints summary, unified diff, and writes the
# reconciled new content to a persistent temp file whose path is emitted on
# stdout as `==> NEW_FILE: <path>`. The caller is responsible for copying
# that file onto the target (e.g. via the Claude Code Write tool, or
# `cp <new-file> <target>` in a shell). The script never writes target
# files itself.
#
# If --scope is omitted, the script auto-detects existing empire markers in
# both candidate files and uses the detected scope. With markers in both
# files, both scopes are reconciled. With markers in neither, the script
# exits with code 3 and asks the caller to pass --scope.
#
# Exit codes:
#   0  success (preview shown, or already in sync)
#   1  precondition failure (missing tools, etc.)
#   2  unexpected runtime error
#   3  no scope determined and no existing markers — caller must choose

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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

FILTER_PLUGIN=""
REQUESTED_SCOPE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      cat <<EOF
sync-rules.sh — sync empire-* skill routing snippets into a rules file.

Usage:
  sync-rules.sh [plugin] [--scope user|project|both]

  plugin            Optional. Plugin name (e.g. empire-git). When set, only
                    that plugin's marker block is touched in the target
                    file(s); other empire blocks are left.
  --scope <scope>   Choose target scope. Defaults to auto-detect from
                    existing markers.
                       user     -> ~/.claude/CLAUDE.md (or AGENTS.md)
                       project  -> ./AGENTS.md (or CLAUDE.md)
                       both     -> both files

The script writes the reconciled new content to a persistent temp file
and emits the path on stdout as '==> NEW_FILE: <path>'. The caller is
responsible for copying it onto the target.
EOF
      exit 0
      ;;
    --scope)
      [[ -z "${2:-}" ]] && die "--scope requires a value (user, project, or both)"
      case "$2" in
        user | project | both) REQUESTED_SCOPE="$2" ;;
        *) die "Invalid --scope '$2' (must be user, project, or both)" ;;
      esac
      shift 2
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
# Target path resolution
# ---------------------------------------------------------------------------

USER_HOME_CLAUDE="$HOME/.claude"

user_target_path() {
  if [[ -f "$USER_HOME_CLAUDE/CLAUDE.md" ]]; then
    printf '%s' "$USER_HOME_CLAUDE/CLAUDE.md"
  elif [[ -f "$USER_HOME_CLAUDE/AGENTS.md" ]]; then
    printf '%s' "$USER_HOME_CLAUDE/AGENTS.md"
  else
    printf '%s' "$USER_HOME_CLAUDE/CLAUDE.md"
  fi
}

project_target_path() {
  local repo_root="$1"
  if [[ -f "$repo_root/AGENTS.md" ]]; then
    printf '%s' "$repo_root/AGENTS.md"
  elif [[ -f "$repo_root/CLAUDE.md" ]]; then
    printf '%s' "$repo_root/CLAUDE.md"
  else
    printf '%s' "$repo_root/AGENTS.md"
  fi
}

# ---------------------------------------------------------------------------
# Repo root (only required for project scope)
# ---------------------------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

require_repo_root() {
  [[ -n "$REPO_ROOT" ]] || die "Project scope requires a git working tree. Run from a project repo, or pass --scope user."
}

# ---------------------------------------------------------------------------
# Existing-scope detection
# ---------------------------------------------------------------------------

file_has_empire_markers() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qE '^<!-- empire:[^:[:space:]]+:start -->$' "$f"
}

detect_existing_scopes() {
  local has_user=0 has_proj=0
  if file_has_empire_markers "$(user_target_path)"; then has_user=1; fi
  if [[ -n "$REPO_ROOT" ]] && file_has_empire_markers "$(project_target_path "$REPO_ROOT")"; then
    has_proj=1
  fi
  if [[ $has_user -eq 1 && $has_proj -eq 1 ]]; then
    printf 'both'
  elif [[ $has_user -eq 1 ]]; then
    printf 'user'
  elif [[ $has_proj -eq 1 ]]; then
    printf 'project'
  else
    printf 'none'
  fi
}

# ---------------------------------------------------------------------------
# Plugin enumeration (one-shot, scope-independent)
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
# Working directories
# ---------------------------------------------------------------------------

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

INSTALLED_DIR="$TMPDIR_WORK/installed"
mkdir -p "$INSTALLED_DIR"

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
# Per-target reconciliation (called once per scope)
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

list_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -mindepth 1 -type f -exec basename {} \; 2>/dev/null | sort
}

# Reconcile a single target file. Globals it consumes: INSTALLED_DIR,
# FILTER_PLUGIN, APPLY. Globals it sets per call: WORK_RESULT_OPS_COUNT.
reconcile_target() {
  local target="$1" scope_label="$2" scope_root="$3"
  local existing_dir="$TMPDIR_WORK/existing-$scope_label"
  rm -rf "$existing_dir"
  mkdir -p "$existing_dir"

  if [[ -L "$target" ]]; then
    local resolved
    resolved="$(resolve_path "$target")"
    case "$resolved" in
      "$scope_root"/*) ;;
      *) die "Target file resolves outside its scope root: $resolved" ;;
    esac
  fi

  if [[ -f "$target" ]]; then
    awk -v outdir="$existing_dir" '
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
    ' "$target"
  fi

  local scope_names
  scope_names="$({
    list_dir "$INSTALLED_DIR"
    list_dir "$existing_dir"
  } | sort -u)"

  local adds=() updates=() removes=() noops=()

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if [[ -n "$FILTER_PLUGIN" && "$name" != "$FILTER_PLUGIN" ]]; then
      continue
    fi
    local inst="$INSTALLED_DIR/$name"
    local exst="$existing_dir/$name"
    if [[ -f "$inst" && ! -f "$exst" ]]; then
      adds+=("$name")
    elif [[ -f "$inst" && -f "$exst" ]]; then
      if cmp -s "$inst" "$exst"; then
        noops+=("$name")
      else
        updates+=("$name")
      fi
    elif [[ ! -f "$inst" && -f "$exst" ]]; then
      removes+=("$name")
    fi
  done <<<"$scope_names"

  local ops_count=$((${#adds[@]} + ${#updates[@]} + ${#removes[@]}))

  local stripped="$TMPDIR_WORK/stripped-$scope_label.md"
  : >"$stripped"
  if [[ -f "$target" ]]; then
    awk '
      /^<!-- empire:[^:[:space:]]+:start -->$/ { skip = 1; next }
      /^<!-- empire:[^:[:space:]]+:end -->$/ { skip = 0; next }
      skip { next }
      { print }
    ' "$target" >"$stripped"
    awk 'NR==FNR { lines[NR] = $0; total = NR; next } END {
      last = total
      while (last > 0 && lines[last] == "") last--
      for (i = 1; i <= last; i++) print lines[i]
    }' "$stripped" "$stripped" >"$stripped.trim"
    mv "$stripped.trim" "$stripped"
  fi

  local final_names=()
  if [[ -n "$FILTER_PLUGIN" ]]; then
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      if [[ "$name" == "$FILTER_PLUGIN" ]]; then
        [[ -f "$INSTALLED_DIR/$name" ]] && final_names+=("$name")
      else
        [[ -f "$existing_dir/$name" ]] && final_names+=("$name")
      fi
    done <<<"$scope_names"
  else
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      [[ -f "$INSTALLED_DIR/$name" ]] && final_names+=("$name")
    done <<<"$scope_names"
  fi

  local new_file="$TMPDIR_WORK/new-$scope_label.md"
  cp "$stripped" "$new_file"
  if [[ ${#final_names[@]} -gt 0 ]]; then
    if [[ -s "$new_file" ]]; then
      printf '\n' >>"$new_file"
    fi
    local first=1
    for name in "${final_names[@]}"; do
      if [[ "$first" -eq 0 ]]; then
        printf '\n' >>"$new_file"
      fi
      first=0
      if [[ -f "$INSTALLED_DIR/$name" ]]; then
        format_block "$name" "$INSTALLED_DIR/$name" >>"$new_file"
      elif [[ -f "$existing_dir/$name" ]]; then
        format_block "$name" "$existing_dir/$name" >>"$new_file"
      fi
    done
  fi

  printf '\n'
  info "Scope:  $scope_label"
  info "Target: $target"
  if [[ -n "$FILTER_PLUGIN" ]]; then
    info "Filter: $FILTER_PLUGIN"
  fi
  if [[ ${#adds[@]} -gt 0 ]]; then info "Add:    ${adds[*]}"; fi
  if [[ ${#updates[@]} -gt 0 ]]; then info "Update: ${updates[*]}"; fi
  if [[ ${#removes[@]} -gt 0 ]]; then info "Remove: ${removes[*]}"; fi
  if [[ ${#noops[@]} -gt 0 ]]; then info "Noop:   ${noops[*]}"; fi

  if [[ "$ops_count" -eq 0 ]]; then
    success "Already in sync ($scope_label)."
    return 0
  fi

  echo
  local rel_target="${target#"$scope_root"/}"
  if [[ -f "$target" ]]; then
    diff -u --label "a/$rel_target" --label "b/$rel_target" "$target" "$new_file" || true
  else
    diff -u --label /dev/null --label "b/$rel_target" /dev/null "$new_file" || true
  fi

  local persistent_dir="${TMPDIR:-/tmp}/empire-rules-sync-$$"
  mkdir -p "$persistent_dir"
  local persistent_new="$persistent_dir/new-$scope_label.md"
  cp "$new_file" "$persistent_new"

  local resolved_target="$target"
  if [[ -L "$resolved_target" ]]; then
    resolved_target="$(resolve_path "$resolved_target")"
  fi

  echo
  info "NEW_FILE: $persistent_new"
  info "TARGET:   $resolved_target"
}

# ---------------------------------------------------------------------------
# Resolve final scope set
# ---------------------------------------------------------------------------

if [[ -z "$REQUESTED_SCOPE" ]]; then
  detected="$(detect_existing_scopes)"
  case "$detected" in
    user | project | both) REQUESTED_SCOPE="$detected" ;;
    none)
      cat >&2 <<'EOF'
ERROR: No empire markers found in either user (~/.claude/CLAUDE.md) or project (./AGENTS.md) files.
Pass --scope to choose where to write rules:
  --scope user     -> ~/.claude/CLAUDE.md  (recommended; follows install scope)
  --scope project  -> ./AGENTS.md          (per-repo; teammates share via VC)
  --scope both     -> write to both
EOF
      exit 3
      ;;
  esac
fi

case "$REQUESTED_SCOPE" in
  project | both) require_repo_root ;;
esac

case "$REQUESTED_SCOPE" in
  user)
    reconcile_target "$(user_target_path)" "user" "$USER_HOME_CLAUDE"
    ;;
  project)
    reconcile_target "$(project_target_path "$REPO_ROOT")" "project" "$REPO_ROOT"
    ;;
  both)
    reconcile_target "$(user_target_path)" "user" "$USER_HOME_CLAUDE"
    reconcile_target "$(project_target_path "$REPO_ROOT")" "project" "$REPO_ROOT"
    ;;
esac
