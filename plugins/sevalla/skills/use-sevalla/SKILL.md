---
name: use-sevalla
description: >
  Operate Sevalla cloud infrastructure: create projects, provision applications
  and databases, deploy code, manage static sites and object storage, configure
  environment variables and domains, scale processes, set up pipelines, monitor
  logs and metrics, troubleshoot failures, and manage API keys and webhooks.
  Use this skill whenever the user mentions Sevalla, deployments, hosting,
  databases, static sites, object storage, domains, environment variables,
  scaling, logs, metrics, pipelines, backups, or cloud infrastructure
  operations, even if they don't say "Sevalla" explicitly.
allowed-tools: Bash(sevalla-api.sh:*), Bash(curl:*), Bash(which:*), Bash(jq:*)
---

# Sevalla Infrastructure Skill

## Resource Model

Sevalla organizes infrastructure in a strict hierarchy:

- **Company** — Top-level organizational unit. A user can belong to multiple companies. Every resource lives under a company.
- **Project** — Groups related services within a company. Use projects to separate environments (production, staging) or logical units (frontend, backend).
- **Application** — A containerized web app deployed from a Git repository (GitHub, GitLab, or Bitbucket) or a Docker image. Runs on Kubernetes pods. Each application contains one or more **processes**: `web` (HTTP traffic), `worker` (background jobs), `cron` (scheduled tasks), or `job` (one-off runs).
- **Database** — A managed database instance. Supported engines: PostgreSQL, MySQL, MariaDB, Redis, and Valkey. Databases can be connected to applications via internal networking.
- **Static Site** — An HTML/CSS/JS site built from a Git repository and served globally via the Cloudflare CDN (260+ edge locations). Free tier available.
- **Object Storage** — S3-compatible buckets powered by Cloudflare R2. Pricing: $0.02/GB stored per month, no egress fees.
- **Load Balancer** — Routes incoming traffic across multiple application destinations with configurable rules and health checks.

All services deploy to one of **25 GCP data centers** worldwide. Choose a region close to your users for lowest latency.

The API base URL is `https://api.sevalla.com/v3`. Authentication uses Bearer tokens.

## Interacting with Sevalla

### Primary: MCP Tools

If `search` and `execute` MCP tools are available (from the Sevalla MCP server at `mcp.sevalla.com/mcp`), always use them.

- **`search` tool** — Write JavaScript to explore the OpenAPI specification. The `spec` global contains the full resolved API spec. Use it to discover endpoints, parameters, request/response schemas, and required fields before making calls.
- **`execute` tool** — Write JavaScript to call API endpoints. The `sevalla` global provides `sevalla.request({ method, path, query, body })` which handles authentication, base URL, and response parsing automatically.

### Fallback: sevalla-api.sh

If MCP tools are unavailable, use the shell helper script:

```bash
./sevalla-api.sh METHOD PATH [BODY]
```

Requires the `SEVALLA_API_KEY` environment variable to be set. The script automatically adds the Bearer token, sets JSON content headers, and pretty-prints responses with `jq` when available.

Examples:
```bash
./sevalla-api.sh GET /applications
./sevalla-api.sh POST /applications '{"display_name":"my-app","company_id":"xxx"}'
```

## Quick Operations

The eight most common operations with ready-to-use MCP `execute` snippets.

### 1. List Applications

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications", query: { limit: 100 } })
  return res.body
}
```

### 2. Get Application Details

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID" })
  return res.body
}
```

Replace `APP_ID` with the actual application identifier (UUID).

### 3. List Databases

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/databases", query: { limit: 100 } })
  return res.body
}
```

### 4. Trigger Deployment

Deploy the latest commit from the application's default branch:

```js
async () => {
  const res = await sevalla.request({ method: "POST", path: "/applications/APP_ID/deployments", body: {} })
  return res.body
}
```

### 5. View Runtime Logs

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/runtime-logs" })
  return res.body
}
```

### 6. Check Deployment Status

Fetch the most recent deployment to see if it succeeded, failed, or is still in progress:

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/deployments", query: { limit: 1 } })
  return res.body
}
```

### 7. List Environment Variables

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/env-vars" })
  return res.body
}
```

### 8. Get Available Regions

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/clusters" })
  return res.body
}
```

## Routing Table

When the user's request goes beyond the quick operations above, load the appropriate reference file.

| Intent | Reference | Use for |
|---|---|---|
| Create or provision resources | `references/setup.md` | Projects, apps, databases, static sites, object storage, cloning |
| Deploy code or manage releases | `references/deploy.md` | Deployments, builds, rollbacks, pipelines, preview apps |
| Change configuration | `references/configure.md` | Env vars, domains, scaling, networking, IP restrictions, CDN |
| Check health or debug issues | `references/operate.md` | Logs, metrics, backups, health checks, troubleshooting |
| Manage platform resources | `references/manage.md` | API keys, webhooks, load balancers, docker registries |

**Rule:** Load only 1-2 references per request. Never load all of them at once. Pick the most relevant file based on the user's stated intent.

## Execution Rules

1. **MCP-first** — Always prefer the `search` and `execute` MCP tools over the shell fallback. Only use `sevalla-api.sh` when MCP tools are confirmed unavailable.
2. **Search before execute** — Use the `search` tool to discover endpoint details (path parameters, query parameters, request body schemas, required fields) before calling `execute`. Do not guess at parameters.
3. **Confirm destructive actions** — Always ask the user for explicit confirmation before deleting resources, suspending applications, restoring backups, or rolling back deployments. State exactly what will happen.
4. **Verify after mutation** — After any create, update, or delete operation, re-read the resource to confirm the change took effect. Report the verified state to the user.
5. **Pagination** — List endpoints default to 25 items per page (maximum 100). Use `limit` and `offset` query parameters to paginate through larger result sets.
6. **Error handling** — Check `res.status` on every response. Status codes 200, 201, 202, and 204 indicate success. Codes 400 and above indicate errors. Always include `res.body` in error reports so the user can see the API's error message.
7. **Rate limits** — If you receive HTTP 429, wait briefly and retry. Rate limits are 120 requests per minute per company for reads, and 5 requests per minute for resource creation endpoints.

## Composition Patterns

Common multi-step workflows. Follow the steps in order, loading the referenced files as needed.

### First Deploy

1. Create a project (`references/setup.md`)
2. Create an application from a Git repository (`references/setup.md`)
3. Set environment variables (`references/configure.md`)
4. Trigger the initial deployment (`references/deploy.md`)
5. Add a custom domain and SSL (`references/configure.md`)
6. Verify the deployment succeeded and the site is live (`references/operate.md`)

### Fix a Failed Deployment

1. Get the latest deployment status (`references/operate.md`)
2. Read the deployment and runtime logs (`references/operate.md`)
3. Identify the root cause — build failure vs. runtime crash vs. health check timeout
4. Fix the source code or configuration as needed
5. Redeploy, or rollback to the last known good deployment (`references/deploy.md`)

### Add a Database to an Application

1. Provision a new database instance (`references/setup.md`)
2. Create an internal connection between the database and the application (`references/configure.md`)
3. Set the database connection string as environment variables on the application (`references/configure.md`)
4. Redeploy the application so it picks up the new environment variables (`references/deploy.md`)

### Scale for Traffic

1. Check current CPU and memory metrics to establish a baseline (`references/operate.md`)
2. Increase pod size, add replicas, or enable auto-scaling (`references/configure.md`)
3. Monitor metrics after scaling to verify the change reduced resource pressure (`references/operate.md`)

## Response Format

After completing any operation, always report back to the user with:

- **What was done** — The specific action taken, including resource names and identifiers.
- **Result** — Success or failure, with key details: resource IDs, URLs, deployment status, timestamps.
- **Next steps** — Suggest what the user might want to do next (e.g., after creating an app, suggest setting env vars and deploying; after a failed deployment, suggest checking logs).

Keep responses concise. Use tables or bullet lists for multi-item results. Always include resource IDs so the user can reference them in follow-up requests.
