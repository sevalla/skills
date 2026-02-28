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

# ── Colours (ANSI-C quoting so escape chars are real) ─────────────────────

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m'
  MAGENTA=$'\033[0;35m'
  WHITE=$'\033[1;37m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' MAGENTA='' WHITE='' BOLD='' DIM='' RESET=''
fi

# ── Helpers ───────────────────────────────────────────────────────────────

step()    { printf "  %s>%s %s\n" "$CYAN" "$RESET" "$1"; }
ok()      { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
err()     { printf "  %s✗%s %s\n" "$RED" "$RESET" "$1" >&2; }

# ── Banner ────────────────────────────────────────────────────────────────

printf "\n"
printf "%s\n" "$MAGENTA"
printf "   ╔═╗╔═╗╦  ╦╔═╗╦  ╦  ╔═╗\n"
printf "   ╚═╗║╣ ╚╗╔╝╠═╣║  ║  ╠═╣\n"
printf "   ╚═╝╚═╝ ╚╝ ╩ ╩╩═╝╩═╝╩ ╩\n"
printf "%s\n" "$RESET"
printf "   %sSkills Installer%s\n" "$DIM" "$RESET"
printf "\n"

# ── Resolve source directory ──────────────────────────────────────────────

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

# ── Detect AI tools ──────────────────────────────────────────────────────

printf "  %sScanning for AI tools%s\n\n" "$BOLD" "$RESET"

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
    printf "  %s  ·  %s  not found%s\n" "$DIM" "$name" "$RESET"
  fi
done

printf "\n"

if [[ ${#FOUND_NAMES[@]} -eq 0 ]]; then
  err "No supported AI tools detected."
  printf "\n"
  printf "  %sInstall one of these tools first:%s\n\n" "$DIM" "$RESET"
  printf "  %s  Claude Code   https://docs.anthropic.com/en/docs/claude-code%s\n" "$DIM" "$RESET"
  printf "  %s  Cursor        https://cursor.com%s\n" "$DIM" "$RESET"
  printf "  %s  Codex         https://openai.com/codex%s\n" "$DIM" "$RESET"
  printf "  %s  OpenCode      https://opencode.ai%s\n" "$DIM" "$RESET"
  printf "\n"
  exit 1
fi

# ── Install ───────────────────────────────────────────────────────────────

printf "  %sInstalling%s\n\n" "$BOLD" "$RESET"

INSTALLED=0

for i in "${!FOUND_NAMES[@]}"; do
  name="${FOUND_NAMES[$i]}"
  dir="${FOUND_DIRS[$i]}"
  hooks="${FOUND_HOOKS[$i]}"

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

# ── Success ───────────────────────────────────────────────────────────────

printf "\n"
printf "  %s%s✓ Installed for %d tool(s)%s\n" "$GREEN" "$BOLD" "$INSTALLED" "$RESET"
printf "\n"
printf "  ─────────────────────────────────────\n"
printf "\n"
printf "  %sNext steps%s\n\n" "$BOLD" "$RESET"

printf "  %s1.%s Connect the MCP server %s(recommended)%s\n\n" "$CYAN" "$RESET" "$DIM" "$RESET"
printf "     Add to your MCP config:\n\n"
printf "     %s┌──────────────────────────────────────────────────┐%s\n" "$DIM" "$RESET"
printf "     %s│%s  \"sevalla\": {                                   %s│%s\n" "$DIM" "$RESET" "$DIM" "$RESET"
printf "     %s│%s    \"type\": \"url\",                               %s│%s\n" "$DIM" "$RESET" "$DIM" "$RESET"
printf "     %s│%s    \"url\": \"%shttps://mcp.sevalla.com/mcp%s\",        %s│%s\n" "$DIM" "$RESET" "$CYAN" "$RESET" "$DIM" "$RESET"
printf "     %s│%s    \"headers\": {                                 %s│%s\n" "$DIM" "$RESET" "$DIM" "$RESET"
printf "     %s│%s      \"Authorization\": \"Bearer %s<api-key>%s\"       %s│%s\n" "$DIM" "$RESET" "$YELLOW" "$RESET" "$DIM" "$RESET"
printf "     %s│%s    }                                            %s│%s\n" "$DIM" "$RESET" "$DIM" "$RESET"
printf "     %s│%s  }                                              %s│%s\n" "$DIM" "$RESET" "$DIM" "$RESET"
printf "     %s└──────────────────────────────────────────────────┘%s\n" "$DIM" "$RESET"
printf "\n"
printf "  %s2.%s Or just set an API key\n\n" "$CYAN" "$RESET"
printf "     %sexport%s SEVALLA_API_KEY=%s<your-api-key>%s\n" "$DIM" "$RESET" "$YELLOW" "$RESET"
printf "\n"
printf "  %sGet your API key → %s%shttps://app.sevalla.com/api-keys%s\n" "$DIM" "$RESET" "$CYAN" "$RESET"
printf "\n"
