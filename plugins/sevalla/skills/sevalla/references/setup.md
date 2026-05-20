# Setup & Provisioning Reference

Discover existing resources and create new ones: projects, applications, databases, static sites, object storage buckets, plus the resource catalogs you need to pick a region and size.

> **No `company_id` in any body.** The API key already identifies the company. Project IDs are always optional unless stated.

## 1. List & Discover

```js
// Projects
async () => (await sevalla.request({ method: "GET", path: "/projects", query: { limit: 100 } })).body
// Applications
async () => (await sevalla.request({ method: "GET", path: "/applications", query: { limit: 100 } })).body
// Databases
async () => (await sevalla.request({ method: "GET", path: "/databases", query: { limit: 100 } })).body
// Static sites
async () => (await sevalla.request({ method: "GET", path: "/static-sites", query: { limit: 100 } })).body
// Object storage buckets
async () => (await sevalla.request({ method: "GET", path: "/object-storage", query: { limit: 100 } })).body
// Load balancers
async () => (await sevalla.request({ method: "GET", path: "/load-balancers", query: { limit: 100 } })).body
// Pipelines
async () => (await sevalla.request({ method: "GET", path: "/pipelines", query: { limit: 100 } })).body
```

All list endpoints accept `limit` (1–100, default 25) and `offset` (0–10000, default 0).

## 2. Create Project

Only `display_name` is required.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/projects",
    body: { display_name: "my-project" }
  })
  return res.body
}
```

## 3. Create Application

**POST /applications**

| Field | Type | Required | Notes |
|---|---|---|---|
| display_name | string | yes | 2–64 chars |
| cluster_id | string (uuid) | yes | From `GET /resources/clusters` |
| source | string | yes | `privateGit` \| `publicGit` \| `dockerImage` |
| project_id | string (uuid) | no | Omit to skip project assignment |
| git_type | string | conditional | `github` \| `bitbucket` \| `gitlab` (privateGit / publicGit) |
| repo_url | string | conditional | Required for git sources |
| default_branch | string | no | Defaults to repo default |
| docker_image | string | conditional | Required for `dockerImage` |
| docker_registry_credential_id | string (uuid) | no | Required for private images (see `references/manage.md`) |

**Build configuration is not set on create.** After the application is created, use `PATCH /applications/{id}` to set `build_type`, `build_path`, `dockerfile_path`, `docker_context`, `pack_builder`, `buildpacks`, `nixpacks_version`, `build_cache_enabled`, `auto_deploy`, `wait_for_checks`, `allow_deploy_paths`, or `ignore_deploy_paths`. See `references/deploy.md`.

### Private Git

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      display_name: "my-web-app",
      cluster_id: "CLUSTER_ID",
      source: "privateGit",
      git_type: "github",
      repo_url: "https://github.com/org/repo",
      default_branch: "main"
    }
  })
  return res.body
}
```

The Git provider must already be connected to the company — list connected providers with `GET /git/providers`.

### Public Git

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      display_name: "open-source-app",
      cluster_id: "CLUSTER_ID",
      source: "publicGit",
      repo_url: "https://github.com/public-org/public-repo",
      default_branch: "main"
    }
  })
  return res.body
}
```

### Docker Image

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      display_name: "containerized-app",
      cluster_id: "CLUSTER_ID",
      source: "dockerImage",
      docker_image: "docker.io/myorg/myapp:latest"
      // docker_registry_credential_id: "<uuid>"  // required for private images
    }
  })
  return res.body
}
```

Images must be built for `linux/amd64`. On Apple Silicon: `docker build --platform linux/amd64 -t myapp:latest .`

### Build Strategies

- **Nixpacks** (default) — auto-detects language. Supports Node.js, Python, Go, Ruby, PHP, Java, Rust, Deno, Elixir, .NET, Swift, Scala. Configure with `nixpacks.toml`. Pin a version via `nixpacks_version` (e.g. `"1.29"`, `"1.39"`, `"1.41"`).
- **Dockerfile** — full control. Set `dockerfile_path` and `docker_context` on PATCH.
- **Buildpacks** (`build_type: "pack"`) — Cloud Native Buildpacks. Choose a `pack_builder` (`"heroku/builder:22"` or `"heroku/builder:24"`) and pass `buildpacks: [{ order, source }]` with the primary language buildpack last.

## 4. Provision Database

**POST /databases**

| Field | Type | Required | Notes |
|---|---|---|---|
| display_name | string | yes | 2–64 chars |
| type | string | yes | `postgresql` \| `mysql` \| `mariadb` \| `redis` \| `valkey` |
| version | string | yes | Engine version, e.g. `"16"`, `"8.0"` |
| cluster_id | string (uuid) | yes | From `GET /resources/clusters` |
| resource_type_id | string | yes | From `GET /resources/database-resource-types` |
| db_name | string | yes | 2–100 chars; `[a-zA-Z0-9_\-+]+` |
| db_password | string | yes | 4–100 chars; `[a-zA-Z0-9_?<>#@\-=+]+` |
| db_user | string | no | 2–32 chars; cannot be `root` or `postgres` |
| project_id | string (uuid) | no | Optional |
| extensions | object | no | PostgreSQL only — see below |

PostgreSQL extensions:

```json
{ "enable_vector": true, "enable_postgis": false, "enable_cron": false }
```

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/databases",
    body: {
      display_name: "main-postgres",
      type: "postgresql",
      version: "16",
      cluster_id: "CLUSTER_ID",
      resource_type_id: "RESOURCE_TYPE_ID",
      db_name: "appdb",
      db_user: "appuser",
      db_password: "STRONG-PW-here",
      extensions: { enable_vector: true }
    }
  })
  return res.body
}
```

The response includes connection details (host, port, username, password, database name) and the database `id`. Connect apps to it via `POST /databases/{id}/internal-connections` — see `references/configure.md`.

## 5. Create Static Site

**POST /static-sites**

| Field | Type | Required | Notes |
|---|---|---|---|
| display_name | string | yes | 2–64 chars |
| repo_url | string | yes | Max 2048 chars |
| default_branch | string | yes | 1–255 chars |
| source | string | no | `privateGit` (default) \| `publicGit` |
| git_type | string | conditional | `github` \| `bitbucket` \| `gitlab` |
| auto_deploy | boolean | no | Deploy on every push |
| is_preview_enabled | boolean | no | Create preview apps for PRs |
| install_command | string | no | e.g. `npm install` |
| build_command | string | no | e.g. `npm run build` |
| published_directory | string | no | e.g. `dist`, `build`, `public` |
| root_directory | string | no | For monorepos |
| node_version | string | no | e.g. `"20"` |
| project_id | string (uuid) | no | |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/static-sites",
    body: {
      display_name: "marketing-site",
      source: "privateGit",
      git_type: "github",
      repo_url: "https://github.com/org/website",
      default_branch: "main",
      install_command: "npm install",
      build_command: "npm run build",
      published_directory: "dist",
      node_version: "20",
      auto_deploy: true,
      is_preview_enabled: true
    }
  })
  return res.body
}
```

Free tier: 100 sites, 600 build minutes/mo, 100 GB bandwidth/mo.

## 6. Create Object Storage Bucket

**POST /object-storage**

| Field | Type | Required | Notes |
|---|---|---|---|
| display_name | string | yes | 2–64 chars |
| location | string | no | `apac`, `eeur`, `enam` (default), `oc`, `weur`, `wnam` |
| jurisdiction | string | no | `default`, `eu`, `fedramp` |
| public_access | boolean | no | Enable public CDN domain (default false) |
| project_id | string (uuid) | no | |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/object-storage",
    body: {
      display_name: "media-assets",
      location: "wnam",
      jurisdiction: "default",
      public_access: true
    }
  })
  return res.body
}
```

The response includes the bucket `id`, S3-compatible endpoint URL, and access key / secret. For CORS, objects, public CDN domain, or credential rotation, see `references/manage.md`.

## 7. Clone Application

**POST /applications/{id}/clone**

| Field | Type | Required | Notes |
|---|---|---|---|
| display_name | string | yes | Must be unique in the company |
| cluster_id | string (uuid) | no | Defaults to source cluster |

Clones the source app's configuration, env vars, processes, and build settings. Useful for staging-from-prod.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/clone",
    body: { display_name: "my-app-staging" }
  })
  return res.body
}
```

## 8. Add Service to Project

**POST /projects/{id}/services**

| Field | Type | Required | Notes |
|---|---|---|---|
| service_id | string (uuid) | yes | The service to move |
| service_type | string | yes | `app` \| `database` \| `pipeline` \| `object-storage` |

Static sites and load balancers are not addable via this endpoint — set their project at creation or via their own PATCH endpoint.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/projects/PROJECT_ID/services",
    body: { service_id: "SERVICE_ID", service_type: "app" }
  })
  return res.body
}
```

Adding a pipeline also moves every stage's app into the project.

Remove with `DELETE /projects/{id}/services/{service_id}`.

## 9. Resource Catalogs

### Clusters (regions)

```js
async () => (await sevalla.request({ method: "GET", path: "/resources/clusters" })).body
```

Pick the region closest to your users. The response includes `id`, `display_name`, and geographic location for each region. **Never hard-code cluster IDs** — they change over time.

### Process sizes (app pods)

```js
async () => (await sevalla.request({ method: "GET", path: "/resources/process-resource-types" })).body
```

| Tier | Examples | Use case |
|---|---|---|
| Hobby | Hobby | Development, testing (single small pod) |
| Standard | S1, S2 | Balanced general workloads |
| Memory-Optimized | M1, M2, M3 | Caching, in-memory processing |
| CPU-Optimized | C1, C2, C3 | Compute-heavy tasks |

### Database sizes

```js
async () => (await sevalla.request({ method: "GET", path: "/resources/database-resource-types" })).body
```

Use the response `id` as `resource_type_id` when creating a database.

### Connected Git providers

```js
async () => (await sevalla.request({ method: "GET", path: "/git/providers" })).body
```

Returns the GitHub / GitLab / Bitbucket installations connected to the company. Required before `source: "privateGit"` can use a given provider.

## 10. Delete Resources

**Always confirm with the user before deleting.** Deletion is irreversible.

```js
// Application
async () => (await sevalla.request({ method: "DELETE", path: "/applications/APP_ID" })).status
// Database
async () => (await sevalla.request({ method: "DELETE", path: "/databases/DB_ID" })).status
// Static site
async () => (await sevalla.request({ method: "DELETE", path: "/static-sites/STATIC_SITE_ID" })).status
// Object storage bucket
async () => (await sevalla.request({ method: "DELETE", path: "/object-storage/BUCKET_ID" })).status
// Project (services inside the project are not deleted)
async () => (await sevalla.request({ method: "DELETE", path: "/projects/PROJECT_ID" })).status
```

A successful delete returns HTTP 204.

## 11. Troubleshooting

| Problem | Cause | Resolution |
|---|---|---|
| "Repo not found" on privateGit | Provider not connected, or repo not authorized | Run `GET /git/providers`. Re-connect or grant repo access in the Sevalla dashboard. |
| 400 — missing required field | Schema mismatch | Inspect the actual body shape via `mcp__sevalla__search`. Field names are precise (`domain_name`, not `name`; `target_id`/`target_type`, not `app_id`). |
| 400 with `company_id` in error | API key already scopes to a company | Remove `company_id` from the body. |
| 400 on database create | Missing `db_name` / `db_password` | Both are required even though the dashboard hides them. |
| Docker image fails to start | Wrong architecture | Rebuild with `--platform linux/amd64`. |
| "Invalid resource type" | Hard-coded or stale ID | Refresh from `GET /resources/process-resource-types` or `/database-resource-types`. |

After any successful create, report the returned `id`. The user will need it for env vars, deploys, scaling, and connections.
