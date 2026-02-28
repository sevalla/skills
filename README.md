<div align="center">

# Sevalla Skills

**Give AI agents the knowledge to manage your entire Sevalla infrastructure.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-FF6723)](https://docs.anthropic.com/en/docs/claude-code)
[![Sevalla API](https://img.shields.io/badge/Sevalla_API-v3-339933)](https://api-docs.sevalla.com)
[![MCP](https://img.shields.io/badge/MCP-compatible-8B5CF6)](https://mcp.sevalla.com/mcp)

</div>

---

Agent skills that teach AI assistants how to operate [Sevalla](https://sevalla.com) cloud infrastructure. Deploy applications, provision databases, manage static sites, configure domains, scale processes, and troubleshoot failures — all through natural conversation.

Works with the [Sevalla MCP Server](https://github.com/sevalla-hosting/mcp) for direct API access, or standalone with API keys.

## Quick Start

### Claude Code

```bash
claude plugin add sevalla-hosting/skills
```

### Other AI Tools

```bash
curl -fsSL https://sevalla.com/skills.sh | bash
```

Supports Claude Code, Cursor, Codex, and OpenCode. Or clone and run `./scripts/install.sh` manually.

## Setup

### Option 1: MCP Server (Recommended)

Pair with the [Sevalla MCP Server](https://github.com/sevalla-hosting/mcp) for the best experience. The skill uses `search` and `execute` MCP tools to discover and call any of Sevalla's 201 API endpoints.

```json
{
  "mcpServers": {
    "sevalla": {
      "type": "url",
      "url": "https://mcp.sevalla.com/mcp",
      "headers": {
        "Authorization": "Bearer <your-sevalla-api-key>"
      }
    }
  }
}
```

### Option 2: API Key Only

Set `SEVALLA_API_KEY` and the skill falls back to the bundled `sevalla-api.sh` helper script for direct REST API calls.

```bash
export SEVALLA_API_KEY="your-api-key"
```

Get your API key from [app.sevalla.com/api-keys](https://app.sevalla.com/api-keys).

## What Can It Do?

| Category | Operations |
| ------------- | --------------------------------------------------------------------- |
| **Setup** | Create projects, provision apps, databases, static sites, object storage |
| **Deploy** | Trigger deployments, rollback, manage pipelines, preview apps |
| **Configure** | Environment variables, domains, scaling, networking, health checks |
| **Operate** | View logs, check metrics, manage backups, troubleshoot failures |
| **Manage** | API keys, webhooks, load balancers, docker registries |

## How It Works

```
User: "Deploy my app to Sevalla"
       │
       ▼
┌─────────────────────────────────┐
│  SKILL.md (routing layer)       │
│                                 │
│  • Resource model               │
│  • 8 quick operations (inline)  │
│  • Routing table ──────────┐    │
└────────────────────────────┼────┘
                             │
            ┌────────────────┼────────────────┐
            ▼                ▼                ▼
      ┌──────────┐    ┌──────────┐    ┌──────────┐
      │ setup.md │    │deploy.md │    │  ...     │
      │          │    │          │    │          │
      │ Projects │    │ Deploys  │    │ 3 more   │
      │ Apps     │    │ Builds   │    │ reference│
      │ DBs      │    │ Rollback │    │ files    │
      │ Storage  │    │ Pipelines│    │          │
      └──────────┘    └──────────┘    └──────────┘
```

The skill uses **progressive disclosure** — only 1-2 reference files load per request, keeping context usage minimal while covering all 201 API endpoints.

| Layer | Token Budget | Contents |
| --------- | ------------ | ---------------------------------------- |
| SKILL.md | ~200 lines | Resource model, quick ops, routing table |
| Reference | ~200-500 lines each | Full endpoint docs with MCP code snippets |

## Repository Structure

```
plugins/sevalla/
├── skills/use-sevalla/
│   ├── SKILL.md              # Routing skill (loaded on activation)
│   ├── references/
│   │   ├── setup.md          # Projects, apps, databases, static sites, storage
│   │   ├── deploy.md         # Deployments, builds, rollbacks, pipelines
│   │   ├── configure.md      # Env vars, domains, scaling, networking
│   │   ├── operate.md        # Logs, metrics, backups, troubleshooting
│   │   └── manage.md         # API keys, webhooks, load balancers, registries
│   └── scripts/
│       └── sevalla-api.sh    # REST API fallback (when MCP unavailable)
└── hooks/
    ├── hooks.json            # Auto-approve Sevalla API calls
    └── auto-approve-mcp.sh
```

## Contributing

See [AGENTS.md](AGENTS.md) for development guidelines, authoring conventions, and testing instructions.

## License

[MIT](LICENSE)
