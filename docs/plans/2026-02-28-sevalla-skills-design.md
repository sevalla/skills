# Sevalla Skills Repository Design

**Date**: 2026-02-28
**Status**: Approved

## Goal

Create a skills repository for AI agents to manage Sevalla PaaS infrastructure. The skills guide agents to provision apps, databases, static sites, and object storage; deploy code; configure environments; monitor health; and manage platform resources — all through Sevalla's MCP server or REST API.

## Architecture

Single `use-sevalla` skill using a routing SKILL.md that dispatches to lazy-loaded reference files by intent. Follows the Railway skills pattern (proven, token-efficient, progressive disclosure).

### Primary interaction: MCP tools

Agents use the Sevalla MCP server at `mcp.sevalla.com/mcp` which exposes 2 tools:
- `search` — discover API endpoints by exploring the OpenAPI spec in a V8 sandbox
- `execute` — call API endpoints via `sevalla.request()` in a V8 sandbox

Fallback: `sevalla-api.sh` script for direct REST API calls via curl.

## Repository Structure

```
sevalla-skills/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── sevalla/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── hooks/
│       │   ├── hooks.json
│       │   └── auto-approve-mcp.sh
│       └── skills/
│           └── use-sevalla/
│               ├── SKILL.md
│               ├── references/
│               │   ├── setup.md
│               │   ├── deploy.md
│               │   ├── configure.md
│               │   ├── operate.md
│               │   └── manage.md
│               └── scripts/
│                   └── sevalla-api.sh
├── scripts/
│   └── install.sh
├── AGENTS.md
├── README.md
└── LICENSE
```

## SKILL.md Design

1. Frontmatter: name, description with trigger words, allowed-tools
2. Resource model: Company → Project → Services (Apps, DBs, Static Sites, Object Storage, Load Balancers)
3. MCP preflight: verify connection and tool availability
4. Quick operations: 8 most common tasks inline
5. Routing table: intent → reference file (load 1-2 max)
6. Execution rules: MCP-first, search before execute, confirm destructive actions, verify after mutation
7. Composition patterns: multi-step workflow chains

## Reference Files

| File | Coverage |
|---|---|
| setup.md | Projects, apps (Git/Docker), databases (6 engines), static sites, object storage, clone |
| deploy.md | Trigger/cancel/rollback deployments, logs, pipelines, promote, preview apps, build config |
| configure.md | Env vars, global vars, domains (custom/wildcard/SSL), scaling (vertical/horizontal/auto), networking, IP restrictions, CDN |
| operate.md | Runtime/access/deployment logs, CPU/memory/request metrics, backups, health checks, suspend/activate, terminal |
| manage.md | API keys, webhooks, load balancers, docker registries, clusters/regions, users |

## MCP Code Pattern

References include ready-to-use JS snippets for the MCP execute tool:
```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications", query: { limit: 100 } })
  return res.body
}
```

## Installer

Multi-tool install.sh supporting Claude Code, Cursor, Codex, and OpenCode.

## Hook System

Auto-approve Bash calls using sevalla-api.sh for non-MCP environments.
