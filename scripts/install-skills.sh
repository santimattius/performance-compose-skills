#!/usr/bin/env bash
# Install all performance-compose-skills into supported coding agents.
# Requires: Node.js (for npx). See docs/INSTALL.md for manual per-agent steps.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="${SKILLS_SOURCE:-santimattius/performance-compose-skills}"

AGENTS=(
  claude-code
  cursor
  gemini-cli
  antigravity
  opencode
  codex
)

GLOBAL=0
YES=(-y)
COPY=()

usage() {
  cat <<'EOF'
Usage: install-skills.sh [OPTIONS]

Install all Jetpack Compose performance skills into Claude Code, Cursor,
Gemini CLI, Antigravity, OpenCode, and Codex via the skills CLI.

Options:
  -g, --global     Install to user home (global) instead of current project
  --copy           Copy files instead of symlinking
  --local          Install from this repo clone instead of GitHub
  -h, --help       Show this help

Environment:
  SKILLS_SOURCE    GitHub repo (default: santimattius/performance-compose-skills)

Examples:
  ./scripts/install-skills.sh
  ./scripts/install-skills.sh --global
  ./scripts/install-skills.sh --local
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--global) GLOBAL=1; shift ;;
    --copy) COPY=(--copy); shift ;;
    --local) SOURCE="$REPO_ROOT"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

ARGS=(add "$SOURCE" --skill '*')
if [[ "$GLOBAL" -eq 1 ]]; then
  ARGS+=(-g)
fi
for agent in "${AGENTS[@]}"; do
  ARGS+=(-a "$agent")
done
ARGS+=("${YES[@]}" "${COPY[@]}")

echo "Installing from: $SOURCE"
echo "Agents: ${AGENTS[*]}"
echo "Scope: $([[ "$GLOBAL" -eq 1 ]] && echo global || echo project)"
echo
# NOTE (Plan B for _shared/): npx skills does not install skills/_shared/ automatically
# because it is not a skill (no root SKILL.md). After running this script, copy _shared/
# to each agent's skill root manually if you need CMP cross-links to resolve:
#   cp -R skills/_shared .agents/skills/_shared   # Cursor/Gemini CLI/Antigravity/OpenCode/Codex
#   cp -R skills/_shared .claude/skills/_shared   # Claude Code
# See docs/INSTALL.md §"Shared resources" for the full procedure.

exec npx skills "${ARGS[@]}"
