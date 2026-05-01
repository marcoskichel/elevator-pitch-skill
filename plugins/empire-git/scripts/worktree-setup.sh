#!/usr/bin/env bash
# worktree-setup.sh — Bootstrap a git worktree for parallel AI-agent development.
# Part of the empire Claude Code plugin.
#
# Usage:
#   worktree-setup.sh <branch-name> [--base <base-branch>] [--reopen]
#
# Self-contained: detects the package manager from lockfiles and runs the
# matching install command. Adds .claude/worktrees to .git/info/exclude so the
# host repo's tracked .gitignore stays untouched.

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

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

BRANCH_NAME=""
BASE_BRANCH=""
REOPEN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      [[ -z "${2:-}" ]] && die "--base requires a branch name argument"
      BASE_BRANCH="$2"
      shift 2
      ;;
    --reopen)
      REOPEN=true
      shift
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      [[ -n "$BRANCH_NAME" ]] && die "Unexpected argument: $1 (branch name already set to '$BRANCH_NAME')"
      BRANCH_NAME="$1"
      shift
      ;;
  esac
done

[[ -z "$BRANCH_NAME" ]] && die "Usage: worktree-setup.sh <branch-name> [--base <base-branch>] [--reopen]"

# ---------------------------------------------------------------------------
# Derived paths
# ---------------------------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "Not inside a git repository"

GIT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null)" \
  || die "Could not resolve git common dir"

# Convert slashes to hyphens for a human-readable prefix, then append a short
# hash of the original branch name to prevent collisions between branches that
# only differ in slash-vs-hyphen positions (e.g. feat/a-b vs feat/a/b).
SAFE_BRANCH="$(printf '%s' "$BRANCH_NAME" | tr '/' '-')"
BRANCH_HASH="$(printf '%s' "$BRANCH_NAME" | cksum | awk '{printf "%08x", $1}')"
WORKTREE_DIR="${REPO_ROOT}/.claude/worktrees/${SAFE_BRANCH}-${BRANCH_HASH}"

# Default base branch: main, then master, then current HEAD.
if [[ -z "$BASE_BRANCH" ]]; then
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    BASE_BRANCH="master"
  else
    BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" \
      || die "Cannot determine default base branch"
  fi
fi

# ---------------------------------------------------------------------------
# Step 0 — Ensure repo-local exclude entry (no .gitignore mutation)
# ---------------------------------------------------------------------------

EXCLUDE_FILE="${GIT_COMMON_DIR}/info/exclude"
EXCLUDE_ENTRY=".claude/worktrees"
mkdir -p "$(dirname "$EXCLUDE_FILE")"
touch "$EXCLUDE_FILE"
if ! grep -qxF "$EXCLUDE_ENTRY" "$EXCLUDE_FILE" 2>/dev/null; then
  printf '%s\n' "$EXCLUDE_ENTRY" >>"$EXCLUDE_FILE"
  info "Added '${EXCLUDE_ENTRY}' to .git/info/exclude"
fi

# ---------------------------------------------------------------------------
# Step 1 — Create or reopen the worktree
# ---------------------------------------------------------------------------

if [[ "$REOPEN" = true ]]; then
  if [[ ! -f "$WORKTREE_DIR/.git" ]]; then
    die "Cannot reopen: $WORKTREE_DIR is not a valid worktree (no .git entry found)"
  fi
  info "Reopening existing worktree at ${WORKTREE_DIR}"
else
  git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}" 2>/dev/null \
    || die "Base branch '${BASE_BRANCH}' does not exist locally"

  CHECKED_OUT_IN="$(
    git worktree list --porcelain \
      | awk -v branch="refs/heads/${BRANCH_NAME}" '
          /^worktree / { wt = substr($0, 10) }
          /^branch /   { if ($2 == branch) print wt }
        '
  )"
  if [[ -n "$CHECKED_OUT_IN" ]]; then
    die "Branch '${BRANCH_NAME}' is already checked out in worktree: ${CHECKED_OUT_IN}"
  fi

  if [[ -d "$WORKTREE_DIR" ]]; then
    if [[ ! -f "$WORKTREE_DIR/.git" ]]; then
      warn "Stale worktree directory detected — running git worktree prune"
      git worktree prune
      if [[ -d "$WORKTREE_DIR" ]]; then
        die "Directory ${WORKTREE_DIR} exists but is not a git worktree. Remove it manually."
      fi
    fi
  fi

  mkdir -p "$(dirname "$WORKTREE_DIR")"

  BRANCH_EXISTS=false
  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}" 2>/dev/null; then
    BRANCH_EXISTS=true
  fi

  if [[ "$BRANCH_EXISTS" = true ]]; then
    info "Branch '${BRANCH_NAME}' exists — adding worktree (no new branch)"
    git worktree add "$WORKTREE_DIR" "$BRANCH_NAME"
  else
    info "Creating new branch '${BRANCH_NAME}' from '${BASE_BRANCH}'"
    git worktree add "$WORKTREE_DIR" -b "$BRANCH_NAME" "$BASE_BRANCH"
  fi
fi

# ---------------------------------------------------------------------------
# Step 2 — Copy .env files recursively
# ---------------------------------------------------------------------------

info "Copying .env files from main repo to worktree"

ENV_COUNT=0
while IFS= read -r -d '' env_file; do
  rel_path="${env_file#"${REPO_ROOT}"/}"
  target_dir="${WORKTREE_DIR}/$(dirname "$rel_path")"
  mkdir -p "$target_dir"
  cp "$env_file" "${WORKTREE_DIR}/${rel_path}"
  ENV_COUNT=$((ENV_COUNT + 1))
done < <(
  find "$REPO_ROOT" \
    -maxdepth 10 \
    -name '.env*' \
    -type f \
    -not -path "${REPO_ROOT}/.git/*" \
    -not -path "${REPO_ROOT}/.claude/*" \
    -print0
)

if [[ "$ENV_COUNT" -gt 0 ]]; then
  info "Copied ${ENV_COUNT} .env file(s)"
else
  info "No .env files found to copy"
fi

# ---------------------------------------------------------------------------
# Step 3 — Derive stable port offset
# ---------------------------------------------------------------------------

PORT_OFFSET="$(printf '%s' "$WORKTREE_DIR" | cksum | awk '{print $1 % 100}')"
info "Port offset for this worktree: ${PORT_OFFSET}"

# ---------------------------------------------------------------------------
# Step 4 — Auto-detect package manager and install dependencies
# ---------------------------------------------------------------------------

run_install() {
  local dir="$1"
  if [[ -f "$dir/pnpm-lock.yaml" ]]; then
    info "Detected pnpm — installing dependencies"
    (cd "$dir" && pnpm install --frozen-lockfile)
  elif [[ -f "$dir/yarn.lock" ]]; then
    info "Detected yarn — installing dependencies"
    (cd "$dir" && yarn install --frozen-lockfile)
  elif [[ -f "$dir/bun.lockb" || -f "$dir/bun.lock" ]]; then
    info "Detected bun — installing dependencies"
    (cd "$dir" && bun install --frozen-lockfile)
  elif [[ -f "$dir/package-lock.json" ]]; then
    info "Detected npm — installing dependencies"
    (cd "$dir" && npm ci)
  elif [[ -f "$dir/uv.lock" ]]; then
    info "Detected uv — installing dependencies"
    (cd "$dir" && uv sync)
  elif [[ -f "$dir/poetry.lock" ]]; then
    info "Detected poetry — installing dependencies"
    (cd "$dir" && poetry install)
  elif [[ -f "$dir/Pipfile.lock" ]]; then
    info "Detected pipenv — installing dependencies"
    (cd "$dir" && pipenv install --deploy)
  elif [[ -f "$dir/Gemfile.lock" ]]; then
    info "Detected bundler — installing dependencies"
    (cd "$dir" && bundle install)
  elif [[ -f "$dir/Cargo.lock" ]]; then
    info "Detected cargo — fetching dependencies"
    (cd "$dir" && cargo fetch)
  elif [[ -f "$dir/go.sum" ]]; then
    info "Detected go modules — downloading dependencies"
    (cd "$dir" && go mod download)
  else
    info "No recognized lockfile — skipping dependency install"
  fi
}

run_install "$WORKTREE_DIR" || warn "Dependency install failed (continuing)"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
success "Worktree ready!"
echo ""
printf '  %-14s %s\n' "Branch:" "$BRANCH_NAME"
printf '  %-14s %s\n' "Base:" "$BASE_BRANCH"
printf '  %-14s %s\n' "Path:" "$WORKTREE_DIR"
printf '  %-14s %s\n' "Port offset:" "$PORT_OFFSET"
echo ""
