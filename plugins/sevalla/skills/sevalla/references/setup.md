# Setup & Provisioning Reference

This reference covers discovering existing resources and creating new ones on Sevalla: projects, applications, databases, static sites, and object storage buckets.

## 1. List & Discover Resources

### List Projects

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/projects", query: { limit: 100 } })
  return res.body
}
```

### List Applications

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications", query: { limit: 100 } })
  return res.body
}
```

### List Databases

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/databases", query: { limit: 100 } })
  return res.body
}
```

### List Static Sites

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/static-sites", query: { limit: 100 } })
  return res.body
}
```

### List Object Storage Buckets

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/object-storage", query: { limit: 100 } })
  return res.body
}
```

All list endpoints support `limit` (max 100) and `offset` query parameters for pagination. Default page size is 25.

## 2. Create Project

Projects are an optional way to group related resources within a company. You do not need to create a project before provisioning resources — applications, databases, static sites, and storage buckets can all be created directly under a company.

**POST /projects**

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | The company this project belongs to |
| display_name | string | yes | Human-readable project name |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/projects",
    body: {
      company_id: "COMPANY_ID",
      display_name: "my-project"
    }
  })
  return res.body
}
```

The response includes the project `id` needed for all subsequent resource creation.

## 3. Create Application

Applications deploy from three source types: private Git repositories, public Git URLs, or Docker images.

**POST /applications**

### Common fields (all source types)

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | Company identifier |
| project_id | string | no | Project identifier (optional — omit to create without a project) |
| display_name | string | yes | Application name |
| cluster_id | string | yes | Target data center (see section 9) |
| source | string | yes | `"privateGit"`, `"publicGit"`, or `"dockerImage"` |

### Source: Private Git (GitHub / GitLab / Bitbucket)

| Field | Type | Required | Description |
|---|---|---|---|
| git_type | string | yes | `"github"`, `"bitbucket"`, or `"gitlab"` |
| repo_url | string | yes | Full repository URL |
| default_branch | string | yes | Branch to deploy from (e.g. `"main"`) |
| build_type | string | no | `"nixpacks"` (default), `"dockerfile"`, or `"pack"` |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "my-web-app",
      source: "privateGit",
      git_type: "github",
      repo_url: "https://github.com/org/repo",
      default_branch: "main",
      build_type: "nixpacks",
      cluster_id: "CLUSTER_ID"
    }
  })
  return res.body
}
```

### Source: Public Git URL

No authentication needed. Provide the public repository URL directly.

| Field | Type | Required | Description |
|---|---|---|---|
| repo_url | string | yes | Public Git repository URL |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "open-source-app",
      source: "publicGit",
      repo_url: "https://github.com/public-org/public-repo",
      default_branch: "main",
      cluster_id: "CLUSTER_ID"
    }
  })
  return res.body
}
```

### Source: Docker Image

Deploy a pre-built container image.

| Field | Type | Required | Description |
|---|---|---|---|
| docker_image | string | yes | Full image path (e.g. `"docker.io/org/image:tag"`) |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "containerized-app",
      source: "dockerImage",
      docker_image: "docker.io/myorg/myapp:latest",
      cluster_id: "CLUSTER_ID"
    }
  })
  return res.body
}
```

**Important:** Docker images must be built for the `linux/amd64` architecture.

### Build Types

**Nixpacks** (default) — Auto-detects the language and framework from source code. Supports 20+ languages: Node.js, Python, Go, Ruby, PHP, Java, Rust, Deno, Elixir, C#/.NET, Swift, and Scala. Configure build behavior with a `nixpacks.toml` file in the repository root.

**Dockerfile** — Full control over the build process using a standard Dockerfile. Set `dockerfile_path` (path to the Dockerfile relative to repo root) and `docker_context` (build context directory) when the Dockerfile is not at the default location.

**Buildpacks** (`"pack"`) — Heroku-style buildpacks for standardized builds. Set `pack_builder` to specify the builder image and `buildpacks` as an array of buildpack URIs. The primary language buildpack must be listed last in the array.

## 4. Provision Database

### Supported engines and versions

| Engine | Versions |
|---|---|
| PostgreSQL | 9.6, 10, 11, 12, 13, 14, 15, 16, 17 |
| MySQL | 8.0, 9.0 |
| MariaDB | 10.4, 10.5, 10.6, 10.11, 11.0, 11.1 |
| Redis | 5.0, 6.x, 7.x, 8.x |
| Valkey | 7.2 |

**POST /databases**

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | Company identifier |
| project_id | string | no | Project identifier (optional — omit to create without a project) |
| display_name | string | yes | Database name |
| type | string | yes | Engine name (e.g. `"postgresql"`, `"mysql"`, `"mariadb"`, `"redis"`, `"valkey"`) |
| version | string | yes | Engine version (e.g. `"17"`, `"8.0"`) |
| cluster_id | string | yes | Target data center |
| resource_type_id | string | yes | Database size (see section 10) |

### Find available database sizes

Before creating a database, look up valid `resource_type_id` values:

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/database-resource-types" })
  return res.body
}
```

### Create a PostgreSQL database

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/databases",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "main-postgres",
      type: "postgresql",
      version: "17",
      cluster_id: "CLUSTER_ID",
      resource_type_id: "RESOURCE_TYPE_ID"
    }
  })
  return res.body
}
```

The response includes connection details (host, port, username, password, database name) and the database `id`.

## 5. Create Static Site

Static sites are built from Git repositories and served globally via Cloudflare CDN (260+ edge locations).

**Free tier limits:** 100 sites, 600 build minutes per month, 100 GB bandwidth per month.

**POST /static-sites**

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | Company identifier |
| project_id | string | no | Project identifier (optional — omit to create without a project) |
| display_name | string | yes | Site name |
| source | string | yes | `"privateGit"` or `"publicGit"` |
| git_type | string | conditional | Required for privateGit: `"github"`, `"bitbucket"`, or `"gitlab"` |
| repo_url | string | yes | Repository URL |
| default_branch | string | yes | Branch to build from |
| install_command | string | no | Dependency install command (e.g. `"npm install"`) |
| build_command | string | no | Build command (e.g. `"npm run build"`) |
| published_directory | string | no | Output directory to serve (e.g. `"dist"`, `"build"`, `"public"`) |
| root_directory | string | no | Subdirectory containing the site source (for monorepos) |
| node_version | string | no | Node.js version for the build environment |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/static-sites",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "marketing-site",
      source: "privateGit",
      git_type: "github",
      repo_url: "https://github.com/org/website",
      default_branch: "main",
      install_command: "npm install",
      build_command: "npm run build",
      published_directory: "dist"
    }
  })
  return res.body
}
```

## 6. Create Object Storage Bucket

S3-compatible object storage powered by Cloudflare R2. Pricing: $0.02/GB stored per month, no egress fees.

**POST /object-storage**

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | Company identifier |
| project_id | string | no | Project identifier (optional — omit to create without a project) |
| display_name | string | yes | Bucket name |
| location | string | yes | Storage region hint |
| jurisdiction | string | no | Data sovereignty jurisdiction |

**Locations:** `apac` (Asia-Pacific), `eeur` (Eastern Europe), `enam` (Eastern North America), `oc` (Oceania), `weur` (Western Europe), `wnam` (Western North America)

**Jurisdictions:** `default` (no restriction), `eu` (EU data residency), `fedramp` (FedRAMP compliant)

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/object-storage",
    body: {
      company_id: "COMPANY_ID",
      project_id: "PROJECT_ID",
      display_name: "media-assets",
      location: "wnam",
      jurisdiction: "default"
    }
  })
  return res.body
}
```

The response includes the bucket `id`, endpoint URL, and access credentials.

## 7. Clone Application

Create a copy of an existing application with all its configuration (environment variables, build settings, process configuration). Useful for creating staging environments from production.

**POST /applications/{id}/clone**

| Field | Type | Required | Description |
|---|---|---|---|
| display_name | string | yes | Name for the cloned application |
| cluster_id | string | no | Target data center (defaults to same as source) |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/clone",
    body: {
      display_name: "my-app-staging"
    }
  })
  return res.body
}
```

## 8. Add Service to Project

Move or link an existing service into a project.

**POST /projects/{id}/services**

| Field | Type | Required | Description |
|---|---|---|---|
| service_id | string | yes | ID of the service to add |
| service_type | string | yes | Type of the service (e.g. `"application"`, `"database"`, `"static-site"`, `"object-storage"`) |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/projects/PROJECT_ID/services",
    body: {
      service_id: "SERVICE_ID",
      service_type: "application"
    }
  })
  return res.body
}
```

## 9. Find Available Clusters

Returns all 25 GCP data center regions with their IDs. Use a cluster ID when creating applications and databases.

**GET /resources/clusters**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/clusters" })
  return res.body
}
```

Choose the region closest to your users for lowest latency. The response includes the cluster `id`, display name, and geographic location for each region.

## 10. Find Available Pod & Database Sizes

### Pod sizes for applications

**GET /resources/process-resource-types**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/process-resource-types" })
  return res.body
}
```

Common pod size categories:

| Category | Sizes | Typical Use |
|---|---|---|
| Hobby | Hobby | Personal projects, experimentation |
| Standard | S1, S2 | Production workloads with balanced CPU and memory |
| Memory-Optimized | M1, M2, M3 | Caching, in-memory processing, large datasets |
| CPU-Optimized | C1, C2, C3 | Compute-heavy tasks, data processing, compilation |

### Database sizes

**GET /resources/database-resource-types**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/database-resource-types" })
  return res.body
}
```

Use the `id` field from the response as the `resource_type_id` when creating a database.

## 11. Troubleshoot Setup

### "Repo not found"

- Verify the git provider connection is active in the Sevalla dashboard.
- Check that the `repo_url` format matches the provider: `https://github.com/owner/repo`, `https://gitlab.com/owner/repo`, or `https://bitbucket.org/owner/repo`.
- Confirm the Sevalla integration has read access to the repository.
- For private repos, ensure `source` is set to `"privateGit"` and `git_type` matches the provider.

### "Cluster not found"

Fetch valid cluster IDs before creating resources:

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/clusters" })
  return res.body
}
```

Use the `id` field from the response, not the display name.

### "Invalid resource type"

Fetch valid resource type IDs for the service type you are provisioning:

- For application pods: `GET /resources/process-resource-types`
- For databases: `GET /resources/database-resource-types`

### Docker image architecture

Docker images must be built for the `linux/amd64` architecture. Images built on Apple Silicon (ARM64) will fail. Build with the `--platform linux/amd64` flag:

```
docker build --platform linux/amd64 -t myapp:latest .
```

### Missing required fields

All create operations require `company_id`. The `project_id` field is optional — omit it to create resources without a project. If you receive a 400 error about missing fields, verify `company_id` is included in the request body.

### After creating any resource

Always report the returned `id` to the user. They will need it for subsequent operations such as deploying, configuring environment variables, or connecting databases to applications.

---

## Delete Resources

**Always confirm with the user before deleting any resource. Deletion is irreversible.**

### Delete Application

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/applications/APP_ID" })
  return { status: res.status }
}
```

### Delete Database

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/databases/DB_ID" })
  return { status: res.status }
}
```

### Delete Static Site

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/static-sites/STATIC_SITE_ID" })
  return { status: res.status }
}
```

### Delete Object Storage Bucket

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/object-storage/BUCKET_ID" })
  return { status: res.status }
}
```

### Delete Project

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/projects/PROJECT_ID" })
  return { status: res.status }
}
```

A successful delete returns HTTP 204 (No Content).
