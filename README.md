<div align="center">

<img src="https://assets.sevalla.com/brand/logo/svg/sevalla-mark-color.svg" alt="" width="64" height="64" />

# Sevalla agent skills

**Teach your coding agent to deploy and run applications, databases and static sites on Sevalla.**

[![CI](https://github.com/sevalla/skills/actions/workflows/ci.yml/badge.svg)](https://github.com/sevalla/skills/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/version-2.0.0-57534e)](plugins/sevalla/.claude-plugin/plugin.json)
[![License: MIT](https://img.shields.io/badge/license-MIT-57534e)](LICENSE)

[Docs](https://docs.sevalla.com/ai-agents/overview) · [Sevalla](https://sevalla.com)

</div>

The `sevalla` skill shows Claude Code, Codex, Cursor and other coding agents how to deploy and
operate applications, databases and static sites on [Sevalla](https://sevalla.com). It reads your
project before it deploys, works through the Sevalla MCP server (or the `sevalla` CLI, or the
API), and asks before anything that costs money or can't be undone. In Claude Code, the plugin
also connects the [Sevalla MCP server](https://github.com/sevalla/mcp).

## Install

In Claude Code, install the plugin. It adds the skill and the Sevalla MCP server:

```sh
claude plugin install sevalla --marketplace sevalla/skills
```

Or, inside Claude Code, `/plugin install sevalla --marketplace sevalla/skills`.

For Codex, Cursor, OpenCode and other agents, add the skill with the
[skills CLI](https://github.com/vercel-labs/skills), then connect the agent to the MCP server with
its [setup guide](https://docs.sevalla.com/ai-agents/overview):

```sh
npx skills add sevalla/skills
```

Without Node.js, copy the skill folder into the folder your agent loads skills from:

```sh
git clone https://github.com/sevalla/skills.git
cp -R skills/plugins/sevalla/skills/sevalla ~/.claude/skills/
```

## Quick start

1. Install the plugin as above and start Claude Code in your project.
2. Type `/mcp`, select **sevalla**, choose **Authenticate**, then pick your company and the
   permissions in the browser.
3. Ask: "Deploy this project to Sevalla."

The agent reads the project, makes the changes Sevalla needs (port, runtime version, migrations),
creates the application and database, deploys, follows the deployment, and gives you the URL.

## Usage

Ask in your own words. The skill covers the whole life of a service:

| Area | For example |
| --- | --- |
| Deploy | "Deploy this repo", "Host this static site", "Add a Postgres database and connect it" |
| Debug | "Why did the last deployment fail?", "The site returns 502", "Reloading /pricing gives a 404" |
| Configure | "Set STRIPE_KEY on storefront", "Scale the web process to 3 instances", "Add shop.example.com" |
| Ship safely | "Make a staging copy of storefront", "Promote staging to production", "Roll back" |
| Run in production | "Is this ready to go live?", "Back up the database before the migration", "Put the app in maintenance mode" |

The skill is one [`SKILL.md`](plugins/sevalla/skills/sevalla/SKILL.md) with its rules and the
deploy and debug workflows, and reference files the agent opens only when a task needs them:

| File | Covers |
| --- | --- |
| [`deploy.md`](plugins/sevalla/skills/sevalla/references/deploy.md) | Applications, processes, databases, variables, static sites, Docker images, CI/CD, pipelines |
| [`frameworks.md`](plugins/sevalla/skills/sevalla/references/frameworks.md) | What each framework needs, with the docs guide for each |
| [`troubleshooting.md`](plugins/sevalla/skills/sevalla/references/troubleshooting.md) | Builds, rollouts, exit codes, HTTP errors, databases, domains, static sites |
| [`production.md`](plugins/sevalla/skills/sevalla/references/production.md) | Go-live, domains, scaling, health checks, backups, network, cost, API keys |
| [`operations.md`](plugins/sevalla/skills/sevalla/references/operations.md) | Operation IDs for everything the dedicated MCP tools don't cover |
| [`cli.md`](plugins/sevalla/skills/sevalla/references/cli.md) | The same work through the `sevalla` CLI |

## Authentication

The MCP server signs in with OAuth: no key in any file. The agent can reach one company, with the
permissions you choose when you authorize it; pick **Company viewer** to keep it read-only. Without
the MCP server, the skill uses the CLI (`sevalla login`) or an API key in `SEVALLA_API_TOKEN`. See
[API keys](https://docs.sevalla.com/developer-tools/api-keys).

## How it works

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://assets.sevalla.com/brand/diagrams/docs/mcp-flow-dark.svg" />
  <img src="https://assets.sevalla.com/brand/diagrams/docs/mcp-flow-light.svg" alt="Your AI agent calls tools on Sevalla's MCP server, signed in with OAuth or an API key. The server calls the Sevalla API, limited by the key's permissions, to manage your company's applications, databases and static sites." />
</picture>

The MCP server gives the agent the tools; the skill gives it the judgment. The server can't see
your code, so the skill reads it: which product fits, which port and runtime, where migrations
run. It picks the narrowest operation (clone rather than recreate, suspend rather than delete),
asks before anything billed or irreversible, follows each deployment to its end, and keeps secrets
out of the conversation. When the MCP server isn't connected, it falls back to the CLI, then the
API, in the order the docs recommend.

## Examples

- "Deploy this Next.js app with a Postgres database in Frankfurt."
- "The latest deployment of storefront failed. Find out why, don't change anything yet."
- "Make a staging copy of storefront that doesn't touch the production database."
- "Add shop.example.com to storefront and tell me which DNS records to create."
- "What was storefront's p95 response time over the last day?"

## Development

```sh
# Check every operation ID, MCP tool, CLI command, docs link and anchor in the skill
node scripts/check.ts

# Validate the plugin and the marketplace
claude plugin validate plugins/sevalla
claude plugin validate .

# Run the evals with the skill, then with the MCP server alone, and compare
claude plugin eval plugins/sevalla --ablation none --scaffold --allow-tools Edit Write --judge-model sonnet
claude plugin eval plugins/sevalla --ablation none --scaffold --allow-tools Edit Write --judge-model sonnet --disallow-tools Skill
```

The evals answer from mocks of the MCP server in `plugins/sevalla/evals/mocks/`, so they never
touch a Sevalla account. [AGENTS.md](AGENTS.md) has the authoring rules.

Results for version 2.0.0: 11 cases, 3 runs each, judged by Claude Sonnet, one full run per model
and setup. "Fully passed" counts runs where every grader passed. Per case:
[plugins/sevalla/evals/README.md](plugins/sevalla/evals/README.md).

| Model | With the skill | MCP server alone |
| --- | --- | --- |
| Claude Sonnet | 1.00, 33 of 33 runs fully passed | 0.84, 23 of 33 |
| Claude Haiku | 0.97, 30 of 33 | 0.90, 26 of 33 |

Without the skill, agents most often skip the migration job on a first deploy, try a custom
domain on the Hobby size without offering a bigger one, and delete a database an app still uses.

## License

MIT. See [LICENSE](LICENSE).
