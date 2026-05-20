#!/usr/bin/env bash
# auto-approve-mcp.sh
#
# Claude Code PreToolUse hook for Bash tool calls.
# Auto-approves commands that invoke the Sevalla API helper script
# or curl directly against api.sevalla.com. Every other command is
# passed through unchanged so the user is prompted as usual.
#
# Protocol: reads the tool invocation JSON from stdin and emits a
# `hookSpecificOutput` JSON object on stdout when it approves.

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

# Anchored to the start of the command so chained / piped destructive
# operations (e.g., `rm -rf / ; sevalla-api.sh`) are NOT auto-approved.
sevalla_script_pattern='^[[:space:]]*(\./|[A-Za-z0-9_./-]*/)?sevalla-api\.sh([[:space:]]|$)'
sevalla_curl_pattern='^[[:space:]]*((SEVALLA_API_KEY|HTTPS_PROXY|HTTP_PROXY)=([^[:space:]"'"'"']+|"[^"]*"|'"'"'[^'"'"']*'"'"')[[:space:]]+)*curl([[:space:]]+-[A-Za-z]+)*[[:space:]]+([^|;&]+[[:space:]]+)?https://api\.sevalla\.com/'

if [[ "$command" =~ $sevalla_script_pattern ]]; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "sevalla-api.sh call auto-approved"
  }
}
JSON
  exit 0
fi

if [[ "$command" =~ $sevalla_curl_pattern ]]; then
  cat <<'JSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Sevalla API curl auto-approved"
  }
}
JSON
  exit 0
fi

exit 0
