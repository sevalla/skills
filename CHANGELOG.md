# Changelog

## Unreleased

### Changed

- The check script, its CI job and the five eval cases that build a project with `scaffold.sh`
  moved to [sevalla/skills-dev](https://github.com/sevalla/skills-dev): the Claude plugin directory
  accepts only Markdown, text, JSON, YAML and images from organizations that aren't verified.
- `CLAUDE.md` imports `AGENTS.md` instead of being a symlink to it.

## v2.0.0

The skill is rebuilt for the Sevalla MCP server's current tools, with the plugin connecting the
server, and an eval suite that runs against mocks of it.

### Added

- The plugin declares the Sevalla MCP server (`https://mcp.sevalla.com/mcp`).
- References for deploying, frameworks, troubleshooting, production, API operations and the CLI.
- `scripts/check.ts`, run in CI every week: operation IDs and the tool that runs each, MCP tool
  names, CLI commands and flags, docs links and anchors, and version numbers.
- Eval cases for `claude plugin eval`, with mocks of every MCP tool.

### Changed

- The skill works through the MCP server's dedicated and generic tools, then the CLI, then the REST
  API, in the order the docs recommend.

### Removed

- The hook that auto-approved Sevalla API calls, `allowed-tools` pre-approval, the REST helper
  script and the installer script.
