# Sevalla

Deploy and run applications, databases and static sites on [Sevalla](https://sevalla.com) from
Claude. The plugin adds the `sevalla` skill and connects the Sevalla MCP server. The skill reads
your project before it deploys, picks the right product and settings, follows each deployment to
its end, and asks before anything that costs more than you asked for or can't be undone.

## What's included

- **The `sevalla` skill**: the safety rules, the deploy and debug workflows, and reference files
  for frameworks, troubleshooting, production and the CLI.
- **The Sevalla MCP server** (`https://mcp.sevalla.com/mcp`), declared in `.mcp.json`. It gives
  Claude tools to manage your applications, databases, static sites, deployments, domains and
  environment variables.

## Get started

1. Install the plugin. In Claude Code:

   ```sh
   /plugin install sevalla --marketplace sevalla/skills
   ```

2. Type `/mcp`, select **sevalla**, choose **Authenticate**, then pick your company and the
   permissions in the browser. Pick **Company viewer** to keep Claude read-only.
3. Ask: "Deploy this project to Sevalla."

For example: "Why did the last deployment of storefront fail?", "Add a Postgres database and
connect it", "Add shop.example.com to storefront", "Make a staging copy of storefront".

## What it connects to

- **The Sevalla MCP server** at `https://mcp.sevalla.com/mcp`. It signs in with OAuth in your
  browser, so no key is stored in any file. It calls the Sevalla API for the one company you
  authorize, with the permissions you chose.
- **The `sevalla` CLI or the Sevalla REST API**, only when the MCP server isn't connected: the CLI
  if you signed in with `sevalla login`, otherwise `https://api.sevalla.com/v3` with the API key
  you set in `SEVALLA_API_TOKEN`.
- **Sevalla's docs** at `https://docs.sevalla.com`, to look up platform details.

The skill reads your project's files to choose settings, and may edit them for Sevalla (the port,
the runtime version, where migrations run). It never prints environment variable values, database
passwords or API keys. The plugin has no hooks or scripts. The `evals` folder holds test cases for
`claude plugin eval` that answer from mocks; Claude doesn't load it when the plugin runs.

## Links

- [Docs](https://docs.sevalla.com/ai-agents/overview)
- [Support](https://docs.sevalla.com/support/get-help)
- [Source](https://github.com/sevalla/skills)
- License: MIT
