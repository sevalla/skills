#!/usr/bin/env bash
# install.sh
#
# Multi-tool installer for Sevalla Skills.
# Detects installed AI coding tools and copies skill files into each one.
#
# Usage:
#   # From a git clone:
#   git clone https://github.com/sevalla-hosting/skills.git
#   cd skills && ./scripts/install.sh
#
#   # Or pipe from curl:
#   curl -fsSL https://raw.githubusercontent.com/sevalla-hosting/skills/main/scripts/install.sh | bash

set -euo pipefail

# ── Colours & helpers ────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { printf "${BLUE}info${RESET}  %s\n" "$1"; }
ok()      { printf "${GREEN}  ok${RESET}  %s\n" "$1"; }
err()     { printf "${RED}error${RESET} %s\n" "$1" >&2; }

# ── Banner ───────────────────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}  Sevalla Skills Installer${RESET}\n"
printf "  ========================\n\n"

# ── Resolve source directory ─────────────────────────────────────────────────
# If we are running from inside a git clone that contains the expected file
# tree, use it directly. Otherwise (e.g. piped from curl) clone the repo
# into a temporary directory.

TMPDIR_CLEANUP=""

cleanup() {
  if [[ -n "$TMPDIR_CLEANUP" && -d "$TMPDIR_CLEANUP" ]]; then
    rm -rf "$TMPDIR_CLEANUP"
  fi
}
trap cleanup EXIT

resolve_source_dir() {
  # When the script is piped from curl, $0 is "bash" and BASH_SOURCE is unset.
  local script_dir=""

  if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  # Check if we are in the repo (look for plugins/sevalla/skills/use-sevalla/SKILL.md).
  if [[ -n "$script_dir" ]]; then
    local repo_root
    repo_root="$(cd "$script_dir/.." && pwd)"
    if [[ -f "$repo_root/plugins/sevalla/skills/use-sevalla/SKILL.md" ]]; then
      SOURCE_DIR="$repo_root"
      return
    fi
  fi

  # Also check current working directory (user may have cd'd into the clone).
  if [[ -f "./plugins/sevalla/skills/use-sevalla/SKILL.md" ]]; then
    SOURCE_DIR="$(pwd)"
    return
  fi

  # Not in a clone — fetch one.
  info "Cloning sevalla-hosting/skills into a temporary directory..."

  if ! command -v git >/dev/null 2>&1; then
    err "git is required but not found. Please install git and try again."
    exit 1
  fi

  TMPDIR_CLEANUP="$(mktemp -d)"
  git clone --depth 1 --quiet https://github.com/sevalla-hosting/skills.git "$TMPDIR_CLEANUP/skills"
  SOURCE_DIR="$TMPDIR_CLEANUP/skills"
  ok "Cloned to $SOURCE_DIR"
}

resolve_source_dir

SKILL_SRC="$SOURCE_DIR/plugins/sevalla/skills/use-sevalla"
HOOKS_SRC="$SOURCE_DIR/plugins/sevalla/hooks"

# ── Detect AI tools ──────────────────────────────────────────────────────────

declare -a FOUND_TOOLS=()

declare -A TOOL_DIRS=(
  ["Claude Code"]="$HOME/.claude"
  ["Cursor"]="$HOME/.cursor"
  ["OpenAI Codex"]="$HOME/.codex"
  ["OpenCode"]="$HOME/.opencode"
)

info "Detecting installed AI tools..."

for tool in "Claude Code" "Cursor" "OpenAI Codex" "OpenCode"; do
  dir="${TOOL_DIRS[$tool]}"
  if [[ -d "$dir" ]]; then
    ok "Found $tool ($dir)"
    FOUND_TOOLS+=("$tool")
  fi
done

printf "\n"

if [[ ${#FOUND_TOOLS[@]} -eq 0 ]]; then
  err "No supported AI tools detected."
  printf "\n"
  printf "  Looked for configuration directories:\n"
  printf "    Claude Code   ~/.claude/\n"
  printf "    Cursor        ~/.cursor/\n"
  printf "    OpenAI Codex  ~/.codex/\n"
  printf "    OpenCode      ~/.opencode/\n"
  printf "\n"
  printf "  Install one of the above tools first, then re-run this script.\n\n"
  exit 1
fi

# ── Install skill files ─────────────────────────────────────────────────────

copy_skill() {
  local dest="$1"
  mkdir -p "$dest"
  # Copy the entire skill tree (SKILL.md, references/, scripts/).
  cp -R "$SKILL_SRC/"* "$dest/"
  ok "Installed skill files to $dest"
}

copy_hooks() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$HOOKS_SRC/"* "$dest/"
  ok "Installed hooks to $dest"
}

INSTALLED=0

for tool in "${FOUND_TOOLS[@]}"; do
  case "$tool" in
    "Claude Code")
      copy_skill "$HOME/.claude/skills/use-sevalla"
      copy_hooks "$HOME/.claude/hooks/sevalla"
      INSTALLED=$((INSTALLED + 1))
      ;;
    "Cursor")
      copy_skill "$HOME/.cursor/skills/use-sevalla"
      INSTALLED=$((INSTALLED + 1))
      ;;
    "OpenAI Codex")
      copy_skill "$HOME/.codex/skills/use-sevalla"
      INSTALLED=$((INSTALLED + 1))
      ;;
    "OpenCode")
      copy_skill "$HOME/.opencode/skills/use-sevalla"
      INSTALLED=$((INSTALLED + 1))
      ;;
  esac
done

# ── Success ──────────────────────────────────────────────────────────────────

printf "\n"
printf "${GREEN}${BOLD}  Done!${RESET} Installed Sevalla skills for %d tool(s).\n\n" "$INSTALLED"

printf "  ${BOLD}Next steps:${RESET}\n\n"

printf "  ${BOLD}Option 1 — MCP Server (recommended):${RESET}\n"
printf "    Add the Sevalla MCP server to your AI tool's config.\n"
printf "    For Claude Code, add to ~/.claude/claude_desktop_config.json:\n\n"
printf '    {\n'
printf '      "mcpServers": {\n'
printf '        "sevalla": {\n'
printf '          "url": "https://mcp.sevalla.com/mcp",\n'
printf '          "headers": {\n'
printf '            "Authorization": "Bearer YOUR_SEVALLA_API_KEY"\n'
printf '          }\n'
printf '        }\n'
printf '      }\n'
printf '    }\n\n'

printf "  ${BOLD}Option 2 — API key only:${RESET}\n"
printf "    export SEVALLA_API_KEY=\"your-api-key\"\n\n"

printf "  Get your API key from https://app.sevalla.com/ under Settings > API Keys.\n\n"
