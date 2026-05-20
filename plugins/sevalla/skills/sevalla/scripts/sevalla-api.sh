#!/usr/bin/env bash
# sevalla-api.sh
#
# Lightweight wrapper around the Sevalla REST API (v3).
# Intended as a fallback for environments where the MCP server
# is not available.
#
# Usage:
#   ./sevalla-api.sh METHOD PATH [BODY]
#
# Examples:
#   ./sevalla-api.sh GET /applications
#   ./sevalla-api.sh POST /applications '{"display_name":"my-app","cluster_id":"<uuid>","source":"privateGit","git_type":"github","repo_url":"https://github.com/org/repo"}'
#   ./sevalla-api.sh DELETE /applications/app-id
#
# Note: company_id is NEVER passed in the request body — it is inferred from
# the API key.
#
# Authentication (checked in order):
#   1. SEVALLA_API_KEY environment variable
#   2. MCP config files in current or parent directories
#      (.mcp.json, .cursor/mcp.json, codex.json, .opencode/config.json)
#   3. Global config files (~/.claude.json)

set -euo pipefail

BASE_URL="https://api.sevalla.com/v3"

# ---------- usage ----------------------------------------------------------
usage() {
  cat <<'USAGE'
Usage: sevalla-api.sh METHOD PATH [BODY]

Arguments:
  METHOD   HTTP method (GET, POST, PUT, PATCH, DELETE)
  PATH     API path, e.g. /applications
  BODY     Optional JSON request body

Authentication (checked in order):
  1. SEVALLA_API_KEY environment variable
  2. MCP config in current or parent directories
     (.mcp.json, .cursor/mcp.json, codex.json, .opencode/config.json)
  3. Global configs (~/.claude.json)

Examples:
  ./sevalla-api.sh GET /applications
  ./sevalla-api.sh POST /applications '{"display_name":"my-app","cluster_id":"<uuid>","source":"privateGit","git_type":"github","repo_url":"https://github.com/org/repo"}'
  ./sevalla-api.sh DELETE /applications/app-id
USAGE
}

# ---------- argument validation --------------------------------------------
if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

METHOD="$1"
API_PATH="$2"
BODY="${3:-}"

# ---------- API key discovery ----------------------------------------------
# Extract Sevalla API key from a JSON config file using jq.
# Looks for an MCP server entry whose URL contains "sevalla" and returns
# the Authorization header value.
_extract_key_from_mcp_json() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  local key
  key=$(jq -r '
    .. | objects
    | select(.url? // "" | test("sevalla"))
    | .headers?.Authorization? // empty
  ' "$file" 2>/dev/null | head -1)
  [[ -n "$key" ]] && echo "$key" && return 0
  return 1
}

# MCP config filenames to search for in project directories.
_PROJECT_CONFIGS=(".mcp.json" ".cursor/mcp.json" "codex.json" ".opencode/config.json")

# Search for MCP config files in current directory and parents.
_find_project_config() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    for cfg in "${_PROJECT_CONFIGS[@]}"; do
      if [[ -f "$dir/$cfg" ]]; then
        echo "$dir/$cfg"
        return 0
      fi
    done
    dir=$(dirname "$dir")
  done
  return 1
}

_discover_api_key() {
  # 1. Environment variable
  if [[ -n "${SEVALLA_API_KEY:-}" ]]; then
    echo "$SEVALLA_API_KEY"
    return 0
  fi

  # 2. MCP config in current or parent directories
  local config_file
  if config_file=$(_find_project_config); then
    local key
    if key=$(_extract_key_from_mcp_json "$config_file"); then
      echo "$key"
      return 0
    fi
  fi

  # 3. Global config files (any supported AI tool)
  local global_cfg
  for global_cfg in "$HOME/.claude.json"; do
    if [[ -f "$global_cfg" ]]; then
      local key
      if key=$(_extract_key_from_mcp_json "$global_cfg"); then
        echo "$key"
        return 0
      fi
    fi
  done

  return 1
}

API_KEY=$(_discover_api_key) || {
  echo "Error: Could not find Sevalla API key." >&2
  echo "" >&2
  echo "Provide it via one of:" >&2
  echo "  1. export SEVALLA_API_KEY=\"your-api-key\"" >&2
  echo "  2. Add Sevalla MCP server to .mcp.json" >&2
  echo "  3. Add Sevalla MCP server in Claude Code settings" >&2
  exit 1
}

# Strip "Bearer " prefix if present — the curl call adds it.
API_KEY="${API_KEY#Bearer }"

# ---------- build curl args ------------------------------------------------
CURL_ARGS=(
  -s
  -X "$METHOD"
  -H "Authorization: Bearer ${API_KEY}"
  -H "Content-Type: application/json"
)

if [[ -n "$BODY" ]]; then
  CURL_ARGS+=(-d "$BODY")
fi

URL="${BASE_URL}${API_PATH}"

# ---------- execute --------------------------------------------------------
RESPONSE=$(curl "${CURL_ARGS[@]}" "$URL")

# Pretty-print with jq if available; otherwise emit raw JSON.
if command -v jq >/dev/null 2>&1; then
  echo "$RESPONSE" | jq .
else
  echo "$RESPONSE"
fi
