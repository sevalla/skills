#!/usr/bin/env bash
# auto-approve-mcp.sh
#
# Claude Code PreToolUse hook for Bash tool calls.
# Auto-approves commands that invoke the Sevalla API helper script
# or curl directly against api.sevalla.com. All other commands are
# passed through (exit 2) so the user is prompted as usual.
#
# Exit codes:
#   0 - auto-approve the tool call
#   2 - pass-through (let the user decide)

set -euo pipefail

TOOL_INPUT="${1:-}"

if [[ -z "$TOOL_INPUT" ]]; then
  exit 2
fi

# Extract the "command" field from the JSON tool input.
COMMAND=$(echo "$TOOL_INPUT" | grep -o '"command"\s*:\s*"[^"]*"' | head -1 | sed 's/^"command"\s*:\s*"//;s/"$//')

if [[ -z "$COMMAND" ]]; then
  exit 2
fi

# Auto-approve if the command references our API helper script.
if echo "$COMMAND" | grep -q 'sevalla-api\.sh'; then
  exit 0
fi

# Auto-approve if the command is a curl call to api.sevalla.com.
if echo "$COMMAND" | grep -qE 'curl.*api\.sevalla\.com'; then
  exit 0
fi

# Everything else: let the user decide.
exit 2
