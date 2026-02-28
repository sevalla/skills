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
#   ./sevalla-api.sh POST /applications '{"display_name":"my-app","company_id":"xxx"}'
#   ./sevalla-api.sh DELETE /applications/app-id
#
# Environment:
#   SEVALLA_API_KEY  (required) — Bearer token for the Sevalla API

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

Environment variables:
  SEVALLA_API_KEY   (required) Bearer token for the Sevalla API

Examples:
  ./sevalla-api.sh GET /applications
  ./sevalla-api.sh POST /applications '{"display_name":"my-app","company_id":"xxx"}'
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

# ---------- API key check --------------------------------------------------
if [[ -z "${SEVALLA_API_KEY:-}" ]]; then
  echo "Error: SEVALLA_API_KEY environment variable is not set." >&2
  echo "Set it with: export SEVALLA_API_KEY=\"your-api-key\"" >&2
  exit 1
fi

# ---------- build curl args ------------------------------------------------
CURL_ARGS=(
  -s
  -X "$METHOD"
  -H "Authorization: Bearer ${SEVALLA_API_KEY}"
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
