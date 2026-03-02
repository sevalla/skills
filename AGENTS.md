# Sevalla Skills -- Development Guide

## Repository Structure

```
.claude-plugin/
  marketplace.json          # Claude Code marketplace listing

plugins/sevalla/
  .claude-plugin/
    plugin.json             # Plugin metadata (name, version, author)
  hooks/
    hooks.json              # Hook definitions for auto-approval
    auto-approve-mcp.sh     # PreToolUse hook: auto-approves Sevalla API calls
  skills/sevalla/
    SKILL.md                # Main routing skill (entry point for all Sevalla operations)
    references/
      setup.md              # Create projects, provision apps/databases/static sites/storage
      deploy.md             # Deployments, builds, rollbacks, pipelines, preview apps
      configure.md          # Env vars, domains, scaling, networking, CDN, IP restrictions
      operate.md            # Logs, metrics, backups, health checks, troubleshooting
      manage.md             # API keys, webhooks, load balancers, docker registries
    scripts/
      sevalla-api.sh        # REST API fallback when MCP tools are unavailable

scripts/
  install.sh                # Multi-tool installer (Claude Code, Cursor, Codex, OpenCode)

AGENTS.md                   # This file — development guide for contributors
CLAUDE.md                   # Symlink to AGENTS.md
README.md                   # User-facing documentation
LICENSE                     # MIT
```

## Authoring Guidelines

### SKILL.md

- Keep concise and routing-focused — it is a dispatcher, not an encyclopedia
- Under 300 lines
- Quick operations section for the 8 most common tasks
- Routing table maps intent to reference files
- Include composition patterns for multi-step workflows

### Reference Files

- One file per operational domain (setup, deploy, configure, operate, manage)
- Action-oriented with MCP code snippets for every operation
- Include troubleshooting section at the bottom
- Target 200-300 lines per file

### MCP Code Snippets

- Format: `async () => { const res = await sevalla.request({...}); return res.body }`
- Always use the execute tool format
- Include the search tool format for discovery operations
- Replace placeholder IDs with descriptive names (APP_ID, DB_ID, etc.)

### Adding New Operations

1. Identify which reference file the operation belongs to
2. Add the operation with endpoint, body schema, and MCP snippet
3. If it is a very common operation, also add it to Quick Operations in SKILL.md
4. Update routing table if a new category is needed

### Testing Changes

- Install locally: copy `plugins/sevalla/` to `~/.claude/skills/`
- Test with Claude Code by asking Sevalla-related questions
- Verify MCP snippets work against the Sevalla API

## API Reference

- OpenAPI spec: https://api.sevalla.com/v3/openapi.json
- Documentation: https://docs.sevalla.com/
- MCP server: mcp.sevalla.com/mcp
