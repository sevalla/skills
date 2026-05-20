---
name: sevalla
description: >
  Use this skill whenever the user wants to provision, deploy, configure,
  monitor, or troubleshoot anything on Sevalla — applications, databases,
  static sites, object storage, load balancers, domains, environment
  variables, scaling, hibernation, edge cache, R2 buckets, pipelines,
  preview apps, backups, usage alerts, webhooks, or API keys. Triggers on
  any of: "Sevalla", "deploy my app", "create a database", "hibernate",
  "scale up/out", "rotate API key", "purge cache", "set env var",
  "custom domain", "rollback", "GCP region", "R2 bucket", or pasted
  Sevalla dashboard URLs.
allowed-tools: mcp__sevalla__*, Bash(sevalla-api.sh:*), Bash(curl:*), Bash(which:*), Bash(jq:*)
---

# Sevalla Infrastructure Skill

## Resource Model

Sevalla organizes infrastructure in a strict hierarchy. **Authentication is scoped to one company per API key — never pass `company_id` in a request body; it is inferred from the token.**

- **Company** — Top-level account. A user can belong to multiple companies but a single API key is bound to one.
- **Project** — *Optional* grouping of services. Apps, databases, static sites, and buckets can live directly under a company without a project.
- **Application** — Containerized service from a Git repo (GitHub, GitLab, Bitbucket) or a Docker image. Runs on Kubernetes. Each app has one or more **processes**: `web`, `worker`, `cron`, `job`.
- **Database** — Managed PostgreSQL, MySQL, MariaDB, Redis, or Valkey instance. Postgres supports `pgvector`, `postgis`, and `pg_cron` extensions.
- **Static Site** — Built from Git, served via Cloudflare CDN. Free tier includes 100 sites, 600 build minutes/mo, 100 GB bandwidth/mo.
- **Object Storage** — S3-compatible buckets on Cloudflare R2. $0.02/GB/mo stored, no egress fees.
- **Load Balancer** — Routes traffic across multiple backends (apps, static sites, buckets, external URLs, nested LBs) with weighted or geographic rules.
- **Pipeline** — Multi-stage promotion flow (e.g., dev → staging → prod) plus preview apps for pull requests.

Deploy targets are GCP data centers worldwide. Look up valid regions with `GET /resources/clusters` — do not hard-code IDs.

API base URL: `https://api.sevalla.com/v3`. Authentication: `Authorization: Bearer <api-key>`.

## Interacting with Sevalla

### Step 1: Detect Available Tools

Before any API call, choose the interface:

1. Check whether `mcp__sevalla__search` and `mcp__sevalla__execute` are in your tool set.
2. **MCP tools available** → use them. They handle auth, base URL, and response parsing. Skip to "Using MCP Tools".
3. **MCP tools missing** → fall back to `sevalla-api.sh`. Tell the user: *"Sevalla MCP server isn't connected. Falling back to the REST script. Reconnect the MCP server for the primary interface."*

Never skip detection. Do not jump to the shell script while the MCP tools are present.

### Using MCP Tools (Primary)

The Sevalla MCP server (`mcp.sevalla.com/mcp`) exposes two tools:

- **`mcp__sevalla__search`** — Run JavaScript against the resolved OpenAPI spec (`spec` global). Use it to discover paths, parameters, request/response shapes, and required fields *before* calling `execute`.
- **`mcp__sevalla__execute`** — Run JavaScript that calls `sevalla.request({ method, path, query, body })`. Handles auth, base URL, and JSON parsing.

Discover endpoints for a resource:

```js
async () => {
  const out = []
  for (const [path, methods] of Object.entries(spec.paths)) {
    if (path.includes("applications")) {
      for (const [method, op] of Object.entries(methods)) {
        out.push({ method: method.toUpperCase(), path, summary: op.summary })
      }
    }
  }
  return out
}
```

Inspect the exact body schema for a write operation:

```js
async () => spec.paths["/applications"].post.requestBody.content["application/json"].schema
```

### Using sevalla-api.sh (Fallback)

```bash
./sevalla-api.sh METHOD PATH [BODY]
```

Auto-discovers the API key in this order:
1. `SEVALLA_API_KEY` env var
2. MCP config files in current or parent directories (`.mcp.json`, `.cursor/mcp.json`, `codex.json`, `.opencode/config.json`)
3. `~/.claude.json`

```bash
./sevalla-api.sh GET /applications
./sevalla-api.sh POST /applications '{"display_name":"my-app","cluster_id":"<uuid>","source":"privateGit","git_type":"github","repo_url":"https://github.com/org/repo"}'
```

## Quick Operations

The most common operations. Use these with `mcp__sevalla__execute`; for the shell fallback, translate to `./sevalla-api.sh METHOD PATH [BODY]`.

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

### 3. List Databases

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/databases", query: { limit: 100 } })
  return res.body
}
```

### 4. Trigger a Fresh Deployment

Pass `branch` for a Git app or `docker_image` for a container app. Omit both to deploy the configured default branch / image.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/deployments",
    body: { branch: "main" }
  })
  return res.body
}
```

### 5. Restart Without Rebuilding

Use `is_restart: true` to redeploy the existing build artifact (skips the build step — fastest way to pick up new env vars).

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/deployments",
    body: { is_restart: true }
  })
  return res.body
}
```

### 6. Check Latest Deployment Status

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/deployments", query: { limit: 1 } })
  return res.body
}
```

### 7. View Runtime Logs

```js
async () => {
  const res = await sevalla.request({
    method: "GET",
    path: "/applications/APP_ID/runtime-logs",
    query: { limit: 500 }
  })
  return res.body
}
```

`from` and `to` default to "1 hour ago → now" and require ISO 8601 with a `Z` suffix.

### 8. List Environment Variables

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/env-vars" })
  return res.body
}
```

## Worked Example: Deploy a Node.js App from Zero

A complete first-deploy. Copy the structure when the user has a fresh repo with no Sevalla resources yet.

```js
// 1. Look up region and pod size IDs
async () => {
  const [clusters, sizes] = await Promise.all([
    sevalla.request({ method: "GET", path: "/resources/clusters" }),
    sevalla.request({ method: "GET", path: "/resources/process-resource-types" })
  ])
  return { clusters: clusters.body, sizes: sizes.body }
}

// 2. Create the application (no company_id — inferred from the API key)
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      display_name: "shop-api",
      cluster_id: "<cluster-id-from-step-1>",
      source: "privateGit",
      git_type: "github",
      repo_url: "https://github.com/acme/shop-api",
      default_branch: "main"
    }
  })
  return res.body  // capture .id as APP_ID
}

// 3. Set env vars (both buildtime and runtime by default)
async () => {
  for (const v of [
    { key: "NODE_ENV", value: "production" },
    { key: "DATABASE_URL", value: "postgres://..." }
  ]) {
    await sevalla.request({ method: "POST", path: "/applications/APP_ID/env-vars", body: v })
  }
}

// 4. Trigger the first deploy
async () => (await sevalla.request({
  method: "POST",
  path: "/applications/APP_ID/deployments",
  body: { branch: "main" }
})).body

// 5. Attach a custom domain (note: field is `domain_name`, not `name`)
async () => (await sevalla.request({
  method: "POST",
  path: "/applications/APP_ID/domains",
  body: { domain_name: "api.acme.com" }
})).body  // response includes the DNS records to add

// 6. Verify
async () => (await sevalla.request({
  method: "GET",
  path: "/applications/APP_ID/deployments",
  query: { limit: 1 }
})).body  // status should reach "success"
```

After step 6, if `status` is `failed`, fetch `/applications/APP_ID/deployments/{id}/logs`. If the app is up but unreachable, check the domain status and runtime logs.

## Reading API Errors

`sevalla.request` always returns `{ status, body }`. Surface both to the user when something fails.

| Status | Meaning | Common cause | Action |
|---|---|---|---|
| 400 | Validation failed | Wrong field name or missing required field | Inspect the body shape with `mcp__sevalla__search` — fields are precise (`domain_name`, `target_id`/`target_type`, `service_id`/`service_type`). |
| 401 | Auth failed | Missing / expired / disabled API key | `GET /api-keys/validate`. Rotate or replace the key. |
| 403 | Insufficient scope | Key lacks the capability for this action | `GET /resources/rbac/api-key-permissions`. Update key roles or use a higher-privilege key. |
| 404 | Resource not found | Wrong ID, wrong company, deleted resource | Re-list the parent resource. IDs in error messages can be cross-checked against `GET /applications`, `GET /databases`, etc. |
| 409 | Conflict | Duplicate name, in-progress deployment, locked resource | Read the error message — often points to the conflicting resource ID. |
| 422 | Semantic error | Valid shape but illegal state (e.g., shrinking a DB) | Read the message; usually a documented constraint (`references/configure.md` lists most). |
| 429 | Rate limited | Sustained burst | Back off and retry. |
| 5xx | Sevalla-side | Transient or incident | Retry once; if it persists, check `docs.sevalla.com/changelog.md`. |

Never retry blindly on 4xx — the error message tells you what to fix.

## Routing Table

When the request exceeds the quick operations above, load the matching reference file. Each row lists the **user phrases** that should trigger it.

| Reference | Triggered by | Covers |
|---|---|---|
| `references/setup.md` | "create app/db/site/bucket", "new project", "provision", "spin up", "clone", "pick a region" | Projects, apps, databases, static sites, object storage, clones, resource catalogs, deletes |
| `references/deploy.md` | "deploy", "redeploy", "restart", "roll back", "cancel deploy", "build is failing", "auto-deploy", "preview app", "pipeline", "promote" | Deployments, build config, pipelines, preview apps, deployment hooks |
| `references/configure.md` | "set env var", "custom domain", "scale", "hibernate", "purge cache", "internal connection", "TCP proxy", "IP allowlist", "readiness probe", "cron schedule" | Env vars, domains, scaling, networking, IP restrictions, CDN, processes, probes, hibernation |
| `references/operate.md` | "logs", "metrics", "is it healthy", "502", "OOM", "crash loop", "backup", "restore", "suspend", "trigger cron", "reset DB password" | Logs, metrics, backups, suspend/activate, web terminal, cron triggers, full triage tree |
| `references/manage.md` | "rotate key", "api key", "webhook", "load balancer", "docker registry", "CORS", "usage alert", "spend limit", "list users" | API keys & RBAC, webhooks, load balancers, docker registries, object storage policies, usage alerts, users |
| `references/discover.md` | "what does the doc say about X", "where is that documented", "changelog", "framework quickstart" | docs.sevalla.com navigation, OpenAPI spec, framework quick-starts |

**Rule:** Load 1–2 references per request, max. If the request spans two areas (e.g., "deploy and then check it's healthy"), load both and compose one response.

## Execution Rules

1. **Detect first** — Run the detection step before every request. Prefer MCP tools; fall back only when they are confirmed absent.
2. **Search before execute** — Inspect the OpenAPI shape (`mcp__sevalla__search`) before any mutating call. Field names are precise.
3. **No `company_id` in bodies** — It is never required; the API key already identifies the company. Project IDs are optional unless explicitly noted.
4. **Confirm destructive actions** — Always confirm before deleting resources, suspending services, restoring backups, rotating credentials, or rolling back deployments. State exactly what will happen.
5. **Verify after mutation** — After a create/update/delete, re-read the resource and report the verified state.
6. **Pagination** — List endpoints default to `limit=25`, max `100`. Use `limit` and `offset` for paging. `offset` max is `10000`.
7. **Surface errors fully** — On non-2xx, include both `res.status` and `res.body` in the user-facing response. See "Reading API Errors" above.
8. **Cite docs when you used them** — When a behavioral claim came from `docs.sevalla.com`, include the doc URL. See `references/discover.md`.

## Composition Patterns

### First Deploy (Git App)

1. (Optional) `POST /projects` to group services — `references/setup.md`.
2. `GET /resources/clusters` and pick a region close to your users.
3. `POST /applications` with `source: "privateGit"`, `git_type`, `repo_url`, optional `default_branch` — `references/setup.md`.
4. `POST /applications/{id}/env-vars` for each variable — `references/configure.md`.
5. Trigger initial deploy with `POST /applications/{id}/deployments` (branch optional) — `references/deploy.md`.
6. `POST /applications/{id}/domains` to attach a custom domain (field is `domain_name`) — `references/configure.md`.
7. Confirm running state via `GET /applications/{id}/deployments?limit=1` and `GET /applications/{id}/runtime-logs` — `references/operate.md`.

### Fix a Failed Deployment

1. `GET /applications/{id}/deployments?limit=1` for the latest status.
2. If build failed: `GET /applications/{id}/deployments/{deployment_id}/logs`.
3. If runtime failed: `GET /applications/{id}/runtime-logs` and `GET /applications/{id}/processes/{process_id}/metrics/exit-codes`.
4. Fix the source, then redeploy. Or roll back via `POST /applications/{id}/deployments/rollback` — confirm with the user first.

### Add a Database

1. Discover sizes: `GET /resources/database-resource-types`.
2. `POST /databases` with `display_name`, `type`, `version`, `cluster_id`, `resource_type_id`, `db_name`, `db_password` (and optional `db_user`, `extensions`).
3. `POST /databases/{db_id}/internal-connections` with `{ target_id: "<app_id>", target_type: "app" }` — same region required.
4. Add the returned internal hostname/port as env vars on the app.
5. Redeploy the app (use `is_restart: true` if no code change) to pick up the new vars.

### Scale for Traffic

1. Baseline: `GET /applications/{id}/processes/{process_id}/metrics/cpu-usage` and `/memory-usage`.
2. Vertical: `PATCH /applications/{id}/processes/{process_id}` with `resource_type_id`.
3. Horizontal: same PATCH with `scaling_strategy: { type: "horizontal", config: { minInstanceCount, maxInstanceCount, targetCpuPercent } }` (max 50 instances; not allowed with persistent storage).
4. Re-check metrics after the change.

### Promote Through a Pipeline

1. `POST /pipelines` (`type: "trunk"` or `"branch"`).
2. `POST /pipelines/{id}/stages` with `{ display_name, insert_before }` for each stage.
3. `POST /pipelines/{id}/stages/{stage_id}/apps` with `{ app_id }` to attach apps.
4. `POST /pipelines/{id}/promote` moves the exact image to the next stage — no rebuild.

## Response Format

After completing an operation, report:

- **What was done** — Action, resource names, IDs.
- **Result** — Success or failure with key fields: IDs, URLs, deployment status, timestamps.
- **Next steps** — Concrete follow-ups (e.g., "Set env vars and trigger a deploy", "Check logs for the runtime crash").

Use tables or bullet lists for multi-item results. Always include resource IDs so the user can reference them in follow-ups.
