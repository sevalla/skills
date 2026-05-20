# Configure — Env Vars, Domains, Scaling, Networking, Processes

Reference for changing configuration on running resources. Env var changes do **not** take effect until the app is redeployed — use `is_restart: true` for fast pickup (`references/deploy.md`).

## 1. Application Environment Variables

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/{id}/env-vars` | — |
| Create | POST | `/applications/{id}/env-vars` | `{ key, value, is_runtime?, is_buildtime? }` |
| Update | PUT | `/applications/{id}/env-vars/{env_var_id}` | `{ key?, value?, is_runtime?, is_buildtime? }` |
| Delete | DELETE | `/applications/{id}/env-vars/{env_var_id}` | — |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/env-vars",
    body: { key: "DATABASE_URL", value: "postgres://...", is_runtime: true, is_buildtime: false }
  })
  return res.body
}
```

### Rules

- **Key characters**: `[a-zA-Z0-9_]+`. No hyphens, dots, or spaces.
- **Variable referencing**: use `${OTHER_KEY}` inside a value. Example: `postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/db`.
- **Scoping**: `is_runtime` and `is_buildtime` both default to **true**. Set explicitly to limit a variable to one phase.
- **Value max length**: 32768 chars.
- **Redeploy required** for any change to take effect.

## 2. Sevalla-Injected Variables

Auto-set on every process at runtime:

| Variable | Description |
|---|---|
| `SVL_COMPANY_ID` | Company identifier |
| `SVL_APP_ID` | Application identifier |
| `SVL_APP_NAME` | Application name |
| `SVL_PROCESS_ID` | Process identifier |
| `SVL_PROCESS_TYPE` | `web` \| `worker` \| `cron` \| `job` |
| `SVL_DEPLOYMENT_ID` | Current deployment identifier |
| `SVL_DEPLOYMENT_INITIATED_BY` | Username or `"system"` |
| `SVL_DEPLOYMENT_TRIGGER` | `manual`, `git_push`, `api`, etc. |
| `SVL_DEPLOYMENT_COMMIT_SHA` | Commit SHA |
| `SVL_DEPLOYMENT_BRANCH` | Git branch |
| `SVL_DEPLOYMENT_DOCKER_IMAGE` | Image URL |
| `PORT` | Port the process should listen on |

Bind your HTTP server to `0.0.0.0:$PORT`.

## 3. Global Environment Variables

Company-wide, automatically deployed to every application. App-scoped variables with the same key win.

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/global-env-vars` | — |
| Create | POST | `/applications/global-env-vars` | `{ key, value }` |
| Update | PUT | `/applications/global-env-vars/{id}` | `{ key?, value? }` |
| Delete | DELETE | `/applications/global-env-vars/{id}` | — |

## 4. Static Site Environment Variables

Static sites use a **different schema** than apps — `is_runtime` / `is_buildtime` do not apply.

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/static-sites/{id}/env-vars` | — |
| Create | POST | `/static-sites/{id}/env-vars` | `{ key, value, is_production?, is_preview?, branch? }` |
| Update | PUT | `/static-sites/{id}/env-vars/{env_var_id}` | same fields |
| Delete | DELETE | `/static-sites/{id}/env-vars/{env_var_id}` | — |

| Field | Default | Notes |
|---|---|---|
| `is_production` | true | Available in production builds |
| `is_preview` | true | Available in preview-app builds |
| `branch` | — | Scope to a single Git branch |

## 5. Custom Domains

The field is `domain_name`, not `name`.

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/{id}/domains` | — |
| Add | POST | `/applications/{id}/domains` | `{ domain_name, is_wildcard?, custom_ssl_cert?, custom_ssl_key? }` |
| Delete | DELETE | `/applications/{id}/domains/{domain_id}` | — |
| Set primary | POST | `/applications/{id}/domains/{domain_id}/set-primary` | — |
| Refresh verification | POST | `/applications/{id}/domains/{domain_id}/refresh-status` | — |
| Toggle (enable/disable) | POST | `/applications/{id}/domains/{domain_id}/toggle` | — |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/domains",
    body: { domain_name: "app.example.com" }
  })
  return res.body
}
```

The response includes the DNS records you must add:

1. **TXT** for ownership verification (`_cf-custom-hostname.<your-domain>`)
2. **CNAME** for SSL validation (`_acme-challenge.<your-domain>`)
3. **A** records (or **CNAME**) pointing your domain at Sevalla

Status progresses: `VERIFICATION` → `VERIFIED` (DNS confirmed, SSL provisioning) → `POINTING` (serving traffic). Propagation can take up to 48 hours; use `refresh-status` to re-check on demand.

### Wildcards & custom SSL

- `is_wildcard: true` covers `*.yourdomain.com`.
- Provide `custom_ssl_cert` and `custom_ssl_key` (PEM) to skip auto-provisioning. Both must be set together.
- Otherwise SSL is auto-provisioned via Cloudflare (free).
- Custom domains require a paid pod tier — Hobby pods only get the default `*.sevalla.app` system domain.

### Static sites & load balancers

The exact same endpoints exist for static sites (`/static-sites/{id}/domains/...`) and load balancers (`/load-balancers/{id}/domains/...`).

## 6. Vertical Scaling (Pod Size)

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID/processes/PROCESS_ID",
    body: { resource_type_id: "NEW_SIZE_ID" }
  })
  return res.body
}
```

Discover sizes: `GET /resources/process-resource-types` (see `references/setup.md`).

## 7. Horizontal Scaling

The `scaling_strategy` object **must** wrap its parameters in `config`.

### Manual

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID/processes/PROCESS_ID",
    body: { scaling_strategy: { type: "manual", config: { instanceCount: 3 } } }
  })
  return res.body
}
```

### Horizontal autoscale

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID/processes/PROCESS_ID",
    body: {
      scaling_strategy: {
        type: "horizontal",
        config: {
          minInstanceCount: 1,
          maxInstanceCount: 10,
          targetCpuPercent: 70,
          targetMemoryPercent: 80,
          scaleUpIntervalSeconds: 60,
          scaleUpIncrement: 1,
          scaleDownIntervalSeconds: 120,
          scaleDownIncrement: 1
        }
      }
    }
  })
  return res.body
}
```

| Field | Range | Notes |
|---|---|---|
| `minInstanceCount` / `maxInstanceCount` | 0–50 | Max 50 instances per process |
| `targetCpuPercent` / `targetMemoryPercent` | 1–100 | Optional; set at least one |
| `scaleUpIncrement` / `scaleDownIncrement` | 1–5 | Instances added/removed per event |

**Constraint:** Processes with persistent storage attached are limited to 1 instance — horizontal scaling is not available until storage is detached.

## 8. Database Scaling

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/databases/DB_ID",
    body: { resource_type_id: "NEW_SIZE_ID" }
  })
  return res.body
}
```

Database resources can only be **increased**. To downsize, create a new database and migrate.

## 9. Internal Networking

Connect apps to databases (or apps to apps, databases to databases) over the private network in the same cluster — no bandwidth charges, lowest latency.

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/databases/{id}/internal-connections` | — |
| Create | POST | `/databases/{id}/internal-connections` | `{ target_id, target_type }` |
| Delete | DELETE | `/databases/{id}/internal-connections/{connection_id}` | — |

`target_type` is `app` or `database` (lowercase).

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/databases/DB_ID/internal-connections",
    body: { target_id: "APP_ID", target_type: "app" }
  })
  return res.body
}
```

After creating the connection, set the returned internal hostname/port as env vars on the application, then redeploy. Both resources must be in the same cluster.

### Toggle external DB access

**POST /databases/{id}/external-connection/toggle** — flips the public connection on or off. No body. Use when running migrations or connecting from local tools; disable when not needed.

## 10. TCP Proxies

Expose a non-HTTP port to the public internet (WebSocket, MQTT, custom TCP).

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/{id}/tcp-proxies` | — |
| Create | POST | `/applications/{id}/tcp-proxies` | `{ process_id, port }` |
| Delete | DELETE | `/applications/{id}/tcp-proxies/{tcp_proxy_id}` | — |

Each proxy gets a unique external port mapped to the specified internal `port`. `process_id` is required.

## 11. Private Ports

Cluster-internal ports for service-to-service traffic. Not exposed publicly.

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/{id}/private-ports` | — |
| Create | POST | `/applications/{id}/private-ports` | `{ process_id, port }` |
| Delete | DELETE | `/applications/{id}/private-ports/{private_port_id}` | — |

## 12. IP Restrictions

Allow- or deny-list IPs / CIDRs on an application or database.

```js
async () => {
  const res = await sevalla.request({
    method: "PUT",
    path: "/applications/APP_ID/ip-restriction",
    body: {
      type: "allow",
      is_enabled: true,
      ip_list: ["203.0.113.0/24", "198.51.100.1"]
    }
  })
  return res.body
}
```

`PUT` requires all three fields. Set `is_enabled: false` to keep the configuration but stop enforcing it. Max 500 entries. Read current state with `GET /applications/{id}/ip-restriction`. Same schema at `/databases/{id}/ip-restriction`.

## 13. CDN & Cache

| Action | Method | Path |
|---|---|---|
| Toggle app CDN | POST | `/applications/{id}/cdn/toggle` |
| Purge app edge + CDN cache | POST | `/applications/{id}/purge-cache` |
| Purge static site CDN | POST | `/static-sites/{id}/purge-cache` |
| Toggle static site pretty URLs | POST | `/static-sites/{id}/pretty-url/toggle` |

CDN propagation takes 2–5 minutes globally after a purge.

## 14. Hibernation

Auto-sleep idle apps. Hibernated apps wake on the next request (8–20 s cold start).

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID",
    body: { hibernation_enabled: true, hibernate_after_seconds: 900 }
  })
  return res.body
}
```

`hibernate_after_seconds` range: 1 to 604800 (7 days). Hibernation requires a single web instance with no persistent storage.

## 15. Health Checks (Probes)

Set readiness and liveness probes via **PATCH /applications/{id}/processes/{process_id}**.

```json
{
  "readiness_probe": {
    "httpGet": { "path": "/health", "port": 8080, "scheme": "HTTP" },
    "initialDelaySeconds": 10,
    "periodSeconds": 10,
    "timeoutSeconds": 5,
    "successThreshold": 1,
    "failureThreshold": 3
  },
  "liveness_probe": {
    "tcpSocket": { "port": 8080 },
    "initialDelaySeconds": 30,
    "periodSeconds": 30,
    "timeoutSeconds": 5,
    "failureThreshold": 3
  }
}
```

| Probe action | Config | Use case |
|---|---|---|
| `httpGet` | `{ path, port, host?, scheme?, httpHeaders? }` | HTTP endpoints returning 2xx/3xx |
| `tcpSocket` | `{ port }` | TCP port accepts connections |
| `exec` | `{ command: ["cmd", "arg"] }` | Custom check; exit 0 = healthy |

Only `web` processes support probes. Readiness gates new pods from receiving traffic; liveness failures restart the container.

## 16. Processes

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/applications/{id}/processes` | — |
| Get | GET | `/applications/{id}/processes/{process_id}` | — |
| Create | POST | `/applications/{id}/processes` | see below |
| Update | PATCH | `/applications/{id}/processes/{process_id}` | partial body |
| Delete | DELETE | `/applications/{id}/processes/{process_id}` | — |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/processes",
    body: {
      display_name: "background-worker",
      type: "worker",
      entrypoint: "node worker.js",
      resource_type_id: "S1_RESOURCE_TYPE_ID"
    }
  })
  return res.body
}
```

### Process types

| Type | Purpose | Internet-accessible | Notes |
|---|---|---|---|
| `web` | HTTP/gRPC traffic | yes | Set `port`, `is_ingress_enabled`, `ingress_protocol` (`http` or `grpc`), probes |
| `worker` | Background processing | no | — |
| `cron` | Scheduled execution | no | Set `schedule` (5-field cron) and `time_zone` (IANA, e.g. `"America/New_York"`) |
| `job` | One-off / lifecycle hooks | no | Set `job_start_policy`: `beforeDeployment`, `afterSuccessDeployment`, `afterFailedDeployment` |

Manually trigger a cron job via **POST /applications/{id}/processes/{process_id}/trigger** (see `references/operate.md`).

## 17. Application Settings

**PATCH /applications/{id}**

| Field | Notes |
|---|---|
| `display_name` | 1–64 chars |
| `auto_deploy`, `default_branch`, `wait_for_checks`, `allow_deploy_paths`, `ignore_deploy_paths` | Auto-deploy config (`references/deploy.md`) |
| `hibernation_enabled`, `hibernate_after_seconds` | Hibernation (section 14) |
| `build_*`, `dockerfile_*`, `pack_builder`, `buildpacks`, `nixpacks_version` | Build config (`references/deploy.md`) |
| `source`, `git_type`, `repo_url`, `docker_image`, `docker_registry_credential_id` | Re-point the source |

Static sites and object storage support `PATCH /static-sites/{id}` and `PATCH /object-storage/{id}` for renaming and resource-specific settings.

## 18. Troubleshooting

| Problem | Cause | Resolution |
|---|---|---|
| Domain stuck on `VERIFICATION` | DNS records missing or wrong | Re-check TXT/CNAME/A records; call `refresh-status`. Allow up to 48 h. |
| SSL won't issue | CAA record blocks Cloudflare | Add Cloudflare to CAA or remove the restrictive record. |
| Env var change has no effect | App not redeployed | Trigger a deploy (`is_restart: true` is enough for runtime-only vars). |
| Can't horizontally scale | Persistent storage attached | Detach the volume; max 1 instance with persistent storage. |
| Internal connection fails | App and DB in different clusters | They must share a cluster. Migrate one to match. |
| IP allowlist blocks real users | CIDR too narrow | Widen `ip_list` or temporarily `is_enabled: false`. |
| Hibernation doesn't sleep app | Multiple instances or persistent storage | Reduce to 1 instance and detach storage. |
| Database resize 4xx | Trying to shrink | DBs only scale up. Create a smaller DB and migrate. |
| `target_type` rejected | Wrong case | Use lowercase `app` or `database`. |
