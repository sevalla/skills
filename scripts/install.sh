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
#   # Via npx:
#   npx skills add sevalla-hosting/skills
#
#   # Or pipe from curl:
#   curl -fsSL https://sevalla.com/skills.sh | bash

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  MAGENTA='\033[0;35m'
  BOLD='\033[1m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' BOLD='' DIM='' RESET=''
fi

# ── Helpers ────────────────────────────────────────────────────────────────

step()    { printf "  ${CYAN}>${RESET} %s\n" "$1"; }
ok()      { printf "  ${GREEN}✓${RESET} %s\n" "$1"; }
err()     { printf "  ${RED}✗${RESET} %s\n" "$1" >&2; }
dimtext() { printf "  ${DIM}%s${RESET}\n" "$1"; }

# ── Banner ─────────────────────────────────────────────────────────────────

printf "\n"
printf "${BOLD}"
printf "  ┌─────────────────────────────────────┐\n"
printf "  │                                     │\n"
printf "  │         ${MAGENTA}Sevalla Skills${RESET}${BOLD}              │\n"
printf "  │                                     │\n"
printf "  │   ${RESET}${DIM}Agent skills for AI coding tools${RESET}${BOLD}   │\n"
printf "  │                                     │\n"
printf "  └─────────────────────────────────────┘\n"
printf "${RESET}\n"

# ── Resolve source directory ───────────────────────────────────────────────

TMPDIR_CLEANUP=""

cleanup() {
  if [[ -n "$TMPDIR_CLEANUP" && -d "$TMPDIR_CLEANUP" ]]; then
    rm -rf "$TMPDIR_CLEANUP"
  fi
}
trap cleanup EXIT

resolve_source_dir() {
  local script_dir=""

  if [[ -n "${BASH_SOURCE[0]:-}" && "${BASH_SOURCE[0]}" != "bash" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "$script_dir" ]]; then
    local repo_root
    repo_root="$(cd "$script_dir/.." && pwd)"
    if [[ -f "$repo_root/plugins/sevalla/skills/use-sevalla/SKILL.md" ]]; then
      SOURCE_DIR="$repo_root"
      return
    fi
  fi

  if [[ -f "./plugins/sevalla/skills/use-sevalla/SKILL.md" ]]; then
    SOURCE_DIR="$(pwd)"
    return
  fi

  step "Downloading sevalla-hosting/skills..."

  if ! command -v git >/dev/null 2>&1; then
    err "git is required but not found. Please install git and try again."
    exit 1
  fi

  TMPDIR_CLEANUP="$(mktemp -d)"
  git clone --depth 1 --quiet https://github.com/sevalla-hosting/skills.git "$TMPDIR_CLEANUP/skills"
  SOURCE_DIR="$TMPDIR_CLEANUP/skills"
  ok "Downloaded"
}

resolve_source_dir

SKILL_SRC="$SOURCE_DIR/plugins/sevalla/skills/use-sevalla"
HOOKS_SRC="$SOURCE_DIR/plugins/sevalla/hooks"

# ── Detect AI tools ───────────────────────────────────────────────────────

printf "  ${BOLD}Scanning for AI tools${RESET}\n\n"

# Tool definitions: name|config_dir|supports_hooks
TOOLS=(
  "Claude Code|$HOME/.claude|yes"
  "Cursor|$HOME/.cursor|no"
  "OpenAI Codex|$HOME/.codex|no"
  "OpenCode|$HOME/.opencode|no"
)

FOUND_NAMES=()
FOUND_DIRS=()
FOUND_HOOKS=()

for entry in "${TOOLS[@]}"; do
  IFS='|' read -r name dir hooks <<< "$entry"
  if [[ -d "$dir" ]]; then
    ok "${BOLD}${name}${RESET}  ${DIM}${dir}${RESET}"
    FOUND_NAMES+=("$name")
    FOUND_DIRS+=("$dir")
    FOUND_HOOKS+=("$hooks")
  else
    dimtext "  ${name}  not found"
  fi
done

printf "\n"

if [[ ${#FOUND_NAMES[@]} -eq 0 ]]; then
  err "No supported AI tools detected."
  printf "\n"
  dimtext "Install one of these tools first:"
  printf "\n"
  dimtext "  Claude Code   https://docs.anthropic.com/en/docs/claude-code"
  dimtext "  Cursor        https://cursor.com"
  dimtext "  Codex         https://openai.com/codex"
  dimtext "  OpenCode      https://opencode.ai"
  printf "\n"
  exit 1
fi

# ── Install ────────────────────────────────────────────────────────────────

printf "  ${BOLD}Installing${RESET}\n\n"

INSTALLED=0

for i in "${!FOUND_NAMES[@]}"; do
  name="${FOUND_NAMES[$i]}"
  dir="${FOUND_DIRS[$i]}"
  hooks="${FOUND_HOOKS[$i]}"

  # Install skill files
  dest="$dir/skills/use-sevalla"
  mkdir -p "$dest"
  cp -R "$SKILL_SRC/"* "$dest/"

  if [[ "$hooks" == "yes" ]]; then
    hooks_dest="$dir/hooks/sevalla"
    mkdir -p "$hooks_dest"
    cp -R "$HOOKS_SRC/"* "$hooks_dest/"
    ok "${name}  ${DIM}skills + hooks${RESET}"
  else
    ok "${name}  ${DIM}skills${RESET}"
  fi

  INSTALLED=$((INSTALLED + 1))
done

# ── Success ────────────────────────────────────────────────────────────────

printf "\n"
printf "  ┌─────────────────────────────────────┐\n"
printf "  │                                     │\n"
printf "  │  ${GREEN}${BOLD}Done!${RESET} Installed for ${BOLD}${INSTALLED}${RESET} tool(s)        │\n"
printf "  │                                     │\n"
printf "  └─────────────────────────────────────┘\n"
printf "\n"

printf "  ${BOLD}Next steps${RESET}\n\n"

printf "  ${CYAN}1.${RESET} Connect the MCP server ${DIM}(recommended)${RESET}\n\n"
printf "     Add to your MCP config:\n\n"
printf "     ${DIM}┌──────────────────────────────────────────────────┐${RESET}\n"
printf "     ${DIM}│${RESET}  \"sevalla\": {                                   ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}    \"type\": \"url\",                               ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}    \"url\": \"${CYAN}https://mcp.sevalla.com/mcp${RESET}\",        ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}    \"headers\": {                                 ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}      \"Authorization\": \"Bearer ${YELLOW}<api-key>${RESET}\"       ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}    }                                            ${DIM}│${RESET}\n"
printf "     ${DIM}│${RESET}  }                                              ${DIM}│${RESET}\n"
printf "     ${DIM}└──────────────────────────────────────────────────┘${RESET}\n"
printf "\n"
printf "  ${CYAN}2.${RESET} Or just set an API key\n\n"
printf "     ${DIM}export${RESET} SEVALLA_API_KEY=${YELLOW}<your-api-key>${RESET}\n"
printf "\n"
printf "  ${DIM}Get your API key at ${CYAN}https://app.sevalla.com/api-keys${RESET}\n"
printf "\n"
