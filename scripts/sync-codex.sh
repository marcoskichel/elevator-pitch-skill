#!/usr/bin/env bash
# sync-codex.sh — Materialize Codex-consumable artifacts from the marketplace source.
# Part of the empire Claude Code plugin marketplace.
#
# skills.sh ships each skill's own directory verbatim, and Codex reads skills from
# .agents/skills. Two artifacts must therefore be generated from the canonical
# source and kept in lockstep with it:
#   1. Specialist personas — copies of plugins/empire-dev/agents/*.md placed in the
#      team-review skill's references/personas/ so they travel with the skill (a
#      skill referenced only relatively stays self-contained across agents).
#   2. .agents/skills/<skill> symlinks — a project-local mirror so Codex discovers
#      these skills when run inside this repo (skills.sh handles external installs).
#
# Usage:
#   sync-codex.sh           # write artifacts (idempotent)
#   sync-codex.sh --check   # verify artifacts are current; exit 1 on drift

set -euo pipefail
shopt -s nullglob

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

CHECK=false
case "${1:-}" in
  --check) CHECK=true ;;
  "") ;;
  *) die "Unknown argument: $1 (usage: sync-codex.sh [--check])" ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

DRIFT=0

# Personas: agent definitions bundled into the team-review skill.
PERSONA_SRC="plugins/empire-dev/agents"
PERSONA_DST="plugins/empire-dev/skills/team-review/references/personas"

# Project-local Codex skill mirror.
MIRROR_DIR=".agents/skills"
EMPIRE_DEV_SKILLS=(team-review socratic-pr-review handoff shape weigh slice)

sync_personas() {
  [[ -d "$PERSONA_SRC" ]] || die "missing persona source: $PERSONA_SRC"

  if $CHECK; then
    local src dst base
    for src in "$PERSONA_SRC"/*.md; do
      base="$(basename "$src")"
      dst="$PERSONA_DST/$base"
      if [[ ! -f "$dst" ]] || ! cmp -s "$src" "$dst"; then
        warn "persona out of sync: $dst"
        DRIFT=1
      fi
    done
    for dst in "$PERSONA_DST"/*.md; do
      base="$(basename "$dst")"
      if [[ ! -f "$PERSONA_SRC/$base" ]]; then
        warn "stale persona (no source): $dst"
        DRIFT=1
      fi
    done
    return
  fi

  mkdir -p "$PERSONA_DST"
  local src dst base
  for dst in "$PERSONA_DST"/*.md; do
    base="$(basename "$dst")"
    [[ -f "$PERSONA_SRC/$base" ]] || rm -f "$dst"
  done
  for src in "$PERSONA_SRC"/*.md; do
    cp "$src" "$PERSONA_DST/$(basename "$src")"
  done
  success "synced personas → $PERSONA_DST"
}

sync_mirror() {
  local skill link target actual

  if $CHECK; then
    for skill in "${EMPIRE_DEV_SKILLS[@]}"; do
      link="$MIRROR_DIR/$skill"
      target="../../plugins/empire-dev/skills/$skill"
      if [[ ! -L "$link" ]]; then
        warn "missing symlink: $link"
        DRIFT=1
        continue
      fi
      actual="$(readlink "$link")"
      if [[ "$actual" != "$target" ]]; then
        warn "symlink target wrong: $link -> $actual (want $target)"
        DRIFT=1
      fi
    done
    return
  fi

  mkdir -p "$MIRROR_DIR"
  for skill in "${EMPIRE_DEV_SKILLS[@]}"; do
    ln -sfn "../../plugins/empire-dev/skills/$skill" "$MIRROR_DIR/$skill"
  done
  success "synced $MIRROR_DIR mirror (${#EMPIRE_DEV_SKILLS[@]} skills)"
}

info "Syncing Codex artifacts (mode: $([[ $CHECK == true ]] && echo check || echo write))"
sync_personas
sync_mirror

if $CHECK; then
  [[ "$DRIFT" -eq 0 ]] || die "Codex artifacts are out of date. Run: scripts/sync-codex.sh"
  success "Codex artifacts up to date"
fi
