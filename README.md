# Sevalla Skills

Agent skills for managing [Sevalla](https://sevalla.com) cloud infrastructure. Deploy applications, provision databases, manage static sites, and operate your entire Sevalla stack through AI agents.

## Quick Install

### Claude Code

```bash
claude plugin add sevalla-hosting/skills
```

Or install manually:

```bash
curl -fsSL https://raw.githubusercontent.com/sevalla-hosting/skills/main/scripts/install.sh | bash
```

### Other AI Tools

Clone and run the installer:

```bash
git clone https://github.com/sevalla-hosting/skills.git
cd skills
./scripts/install.sh
```

Supports Claude Code, Cursor, Codex, and OpenCode.

## Setup

### Option 1: MCP Server (Recommended)

Add the Sevalla MCP server to your AI tool's configuration. The skill will automatically use the `search` and `execute` MCP tools.

For Claude Code, add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "sevalla": {
      "url": "https://mcp.sevalla.com/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_SEVALLA_API_KEY"
      }
    }
  }
}
```

### Option 2: API Key Only

Set the `SEVALLA_API_KEY` environment variable:

```bash
export SEVALLA_API_KEY="your-api-key"
```

The skill will use the `sevalla-api.sh` helper script to call the REST API directly.

Get your API key from the [Sevalla dashboard](https://app.sevalla.com/) under Settings > API Keys.

## What Can It Do?

| Category | Operations |
|---|---|
| **Setup** | Create projects, provision apps/databases/static sites/object storage |
| **Deploy** | Trigger deployments, rollback, manage pipelines, preview apps |
| **Configure** | Environment variables, domains, scaling, networking, health checks |
| **Operate** | View logs, check metrics, manage backups, troubleshoot |
| **Manage** | API keys, webhooks, load balancers, docker registries |

## How It Works

The skill uses a **progressive disclosure** architecture:

1. **SKILL.md** loads when the AI detects Sevalla-related intent
2. **Quick operations** handle the 8 most common tasks inline
3. **Reference files** load on-demand for deeper operations (only 1-2 per request)

This keeps context usage minimal while providing comprehensive coverage of Sevalla's 201 API endpoints.

## Contributing

See [AGENTS.md](AGENTS.md) for development guidelines.

## License

MIT -- see [LICENSE](LICENSE) for details.
