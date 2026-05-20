# Discover — Docs, API Spec, Changelog

Where to look when the API spec or a reference file does not answer a question. **Read these before guessing product behavior.**

## 1. LLM-friendly docs index

`https://docs.sevalla.com/llms.txt` — the authoritative index of every documentation page. Each entry includes the URL, a one-line summary, and the path to the raw markdown.

**Trick:** every doc page has a markdown version. Append `.md` to any `docs.sevalla.com` URL and you'll get LLM-ready markdown:

| Browser URL | LLM URL |
|---|---|
| `https://docs.sevalla.com/applications/deployments` | `https://docs.sevalla.com/applications/deployments.md` |
| `https://docs.sevalla.com/databases/backups` | `https://docs.sevalla.com/databases/backups.md` |

Fetch the index first to discover what exists, then pull the `.md` for the specific topic.

## 2. Top-level documentation areas

| Area | Path | When to read |
|---|---|---|
| Applications overview | `/applications/overview.md` | Resource model, lifecycle, processes |
| Add an application | `/applications/get-started/add-an-application.md` | First-deploy walkthrough |
| Build options | `/applications/build-options/{buildpacks,dockerfile,nixpacks}.md` | Picking / debugging a build strategy |
| Domains | `/applications/domains.md` | DNS records, SSL, wildcards, custom certs |
| Networking | `/applications/networking.md` | Public vs internal, TCP proxies, private ports |
| Edge caching | `/applications/edge-caching.md` | CDN behavior, purge timing |
| Scalability | `/applications/scalability.md` | Pod sizes, vertical/horizontal scaling rules |
| Storage | `/applications/storage.md` | Persistent volumes and limitations |
| Runtime logs | `/applications/runtime-logs.md` | Log retention, filtering |
| Web terminal | `/applications/web-terminal.md` | Shell-into-container behavior |
| Pipelines | `/applications/get-started/pipelines.md` | Multi-stage promotion, preview apps |
| Application troubleshooting | `/applications/troubleshooting/{application-failure,connection-errors,failed-deployment,general,http-status-codes,missing-repository,php-errors,skip-pruning}.md` | Symptom-specific debugging |
| Databases overview | `/databases/overview.md` | Engines, versions, capabilities |
| Backups | `/databases/backups.md` | Daily vs manual, retention, restore behavior |
| Import / export | `/databases/import-export/{postgresql,mysql,mariadb,redis,valkey}.md` | Moving data in or out |
| Database Studio | `/databases/manage-data/database-studio.md` | Built-in SQL editor |
| Static sites overview | `/static-sites/overview.md` | Build pipeline, CDN, free-tier limits |
| Object storage overview | `/object-storage/overview.md` | R2 capabilities, S3 compatibility |
| Load balancers | `/load-balancers/{add-load-balancer,analytics}.md` | Routing types, weights, geo |
| Projects | `/projects/...` | Optional grouping model |
| Usage alerts | `/billing/usage-alerts.md` | Spending notifications |
| Application pricing | `/billing/application-pricing.md` | Pod tier cost |
| Database pricing | `/billing/database-pricing.md` | DB tier cost |
| Static site pricing | `/billing/static-site-pricing.md` | Site quotas and overages |
| Tools — API keys | `/tools/api-keys.md` | Roles, capabilities, rotation |
| Tools — Webhooks | `/tools/webhooks.md` | Signature verification, retries |
| Tools — Global vars | `/tools/global-env-vars.md` | Company-wide configuration |
| Tools — Registries | `/tools/registry-credentials.md` | Private Docker image pulls |
| Compliance & security | `/service-information/...` | SOC 2, GDPR, data centers |
| Changelog | `/changelog.md` | Recent platform changes |

## 3. API reference

| Resource | URL | Use for |
|---|---|---|
| Interactive API docs | `https://api-docs.sevalla.com/` | Human-friendly endpoint browser |
| OpenAPI 3 spec (JSON) | `https://api.sevalla.com/v3/openapi.json` | Source of truth for schemas — fetch this when you need exact field shapes |
| API base URL | `https://api.sevalla.com/v3` | All requests target this prefix |

When using MCP tools, prefer `mcp__sevalla__search` (which already operates on the resolved OpenAPI spec) over fetching the raw JSON.

## 4. Quick-start guides

Language-specific deployment guides at `https://docs.sevalla.com/quick-starts/`:

- JavaScript, TypeScript, Python, Go, Ruby, PHP, Java
- Framework-specific: Next.js, Nuxt, Remix, Astro, SvelteKit, Django, Flask, FastAPI, Rails, Laravel, Spring Boot
- Coding-agent integrations (Claude Code, Cursor, etc.) at `/quick-starts/coding-agents/`

Fetch these when the user is bootstrapping a new app and you want to confirm the recommended `install_command` / `build_command` / `published_directory` / runtime version.

## 5. When to use what

- **Question about an API field, status code, or request shape** → `mcp__sevalla__search` against the OpenAPI spec.
- **Question about *behavior* (hibernation cold-start, free-tier limits, what happens on rollback)** → `docs.sevalla.com/<topic>.md`.
- **"What changed recently?"** → `docs.sevalla.com/changelog.md`.
- **First-time framework deploy** → `docs.sevalla.com/quick-starts/<lang-or-framework>.md`.

Always cite the doc URL in your response when you used it — the user may want to read more.
