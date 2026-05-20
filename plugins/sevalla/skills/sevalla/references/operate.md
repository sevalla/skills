# Operate — Logs, Metrics, Backups, Troubleshooting

Monitor, debug, and run housekeeping on running resources.

## 1. Runtime Logs

Application stdout/stderr.

**GET /applications/{id}/runtime-logs**

| Query | Type | Notes |
|---|---|---|
| `from` | ISO 8601 (`...Z`) | Defaults to 1 hour ago |
| `to` | ISO 8601 (`...Z`) | Defaults to now |
| `filters` | string | JSON-encoded array of `{ key, operator, value | values }`. Example: `[{"key":"severity","operator":"EQUALS","value":"ERROR"}]` |
| `limit` | integer | Default 1000, max 5000 |

```js
async () => {
  const now = new Date().toISOString()
  const oneHourAgo = new Date(Date.now() - 3600_000).toISOString()
  const res = await sevalla.request({
    method: "GET",
    path: "/applications/APP_ID/runtime-logs",
    query: { from: oneHourAgo, to: now, limit: 500 }
  })
  return res.body
}
```

## 2. Access Logs

HTTP request logs (method, path, status, response time, geography).

**GET /applications/{id}/access-logs** — same query params as runtime logs.

```js
async () => {
  const res = await sevalla.request({
    method: "GET",
    path: "/applications/APP_ID/access-logs",
    query: {
      filters: JSON.stringify([{ key: "status_code", operator: "GREATER_THAN_OR_EQUALS", value: 500 }]),
      limit: 500
    }
  })
  return res.body
}
```

Static sites: `GET /static-sites/{id}/access-logs` (identical schema).

## 3. Deployment (Build) Logs

**GET /applications/{id}/deployments/{deployment_id}/logs** — same query params as runtime logs. For static sites: `GET /static-sites/{id}/deployments/{deployment_id}/logs`.

Fetch the latest deployment first if you don't have its ID:

```js
async () => (await sevalla.request({
  method: "GET",
  path: "/applications/APP_ID/deployments",
  query: { limit: 1 }
})).body
```

## 4. Application Metrics

All metrics endpoints require `start`, `end` (both ISO 8601 with `Z`), and `interval_in_seconds`.

| Endpoint | Shows |
|---|---|
| `GET /applications/{id}/metrics/requests-per-minute` | Request rate |
| `GET /applications/{id}/metrics/response-time` | Response time distribution (p50/p95/p99) |
| `GET /applications/{id}/metrics/response-time-avg` | Average response time |
| `GET /applications/{id}/metrics/slowest-requests` | Slowest paths |
| `GET /applications/{id}/metrics/status-codes` | Status-code breakdown over time |
| `GET /applications/{id}/metrics/top-status-codes` | Most frequent status codes |
| `GET /applications/{id}/metrics/top-countries` | Traffic by country |
| `GET /applications/{id}/metrics/top-pages` | Most-visited paths |

```js
async () => {
  const end = new Date().toISOString()
  const start = new Date(Date.now() - 3600_000).toISOString()
  const res = await sevalla.request({
    method: "GET",
    path: "/applications/APP_ID/metrics/requests-per-minute",
    query: { start, end, interval_in_seconds: 60 }
  })
  return res.body
}
```

Static sites expose the same eight endpoints under `/static-sites/{id}/metrics/...`.

## 5. Process Metrics

| Endpoint | Shows |
|---|---|
| `GET /applications/{id}/processes/{process_id}/metrics/cpu-usage` | CPU usage (millicores) |
| `GET /applications/{id}/processes/{process_id}/metrics/cpu-limit` | CPU limit |
| `GET /applications/{id}/processes/{process_id}/metrics/memory-usage` | Memory usage (MiB) |
| `GET /applications/{id}/processes/{process_id}/metrics/memory-limit` | Memory limit |
| `GET /applications/{id}/processes/{process_id}/metrics/instance-count` | Running instances |
| `GET /applications/{id}/processes/{process_id}/metrics/exit-codes` | Exit-code history (useful for crash loops) |

```js
async () => {
  const end = new Date().toISOString()
  const start = new Date(Date.now() - 3600_000).toISOString()
  const query = { start, end, interval_in_seconds: 60 }
  const [cpu, cpuLimit, mem, memLimit] = await Promise.all([
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/cpu-usage", query }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/cpu-limit", query }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/memory-usage", query }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/memory-limit", query })
  ])
  return { cpu: cpu.body, cpuLimit: cpuLimit.body, memory: mem.body, memoryLimit: memLimit.body }
}
```

## 6. Database Metrics

| Endpoint | Shows |
|---|---|
| `GET /databases/{id}/metrics/cpu-usage` | CPU usage |
| `GET /databases/{id}/metrics/cpu-limit` | CPU limit |
| `GET /databases/{id}/metrics/memory-usage` | Memory usage |
| `GET /databases/{id}/metrics/memory-limit` | Memory limit |
| `GET /databases/{id}/metrics/storage-usage` | Storage used |
| `GET /databases/{id}/metrics/storage-limit` | Storage limit |
| `GET /databases/{id}/metrics/used-storage` | Used storage (alt) |
| `GET /databases/{id}/metrics/all-storage` | Combined storage view |

All require `start`, `end`, `interval_in_seconds`.

## 7. Database Backups

Daily automatic backups (7-day retention). Manual backups (14-day retention, up to 5 per database).

| Action | Method | Path | Body |
|---|---|---|---|
| List | GET | `/databases/{id}/backups` | query `?type=daily\|manual` (optional filter) |
| Create manual | POST | `/databases/{id}/backups` | `{ display_name }` (required) |
| Restore | POST | `/databases/{id}/backups/{backup_id}/restore` | — |
| Delete | DELETE | `/databases/{id}/backups/{backup_id}` | — |

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/databases/DB_ID/backups",
  body: { display_name: "Pre-migration snapshot" }
})).body
```

**Restoring overwrites current database contents.** Always confirm with the user first.

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/databases/DB_ID/backups/BACKUP_ID/restore"
})).body
```

## 8. Suspend & Activate

Stop all processes to save costs. Confirm with the user first.

| Action | Method | Path |
|---|---|---|
| Suspend app | POST | `/applications/{id}/suspend` |
| Activate app | POST | `/applications/{id}/activate` |
| Suspend database | POST | `/databases/{id}/suspend` |
| Activate database | POST | `/databases/{id}/activate` |

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/applications/APP_ID/suspend"
})).body
```

## 9. Reset Database Password

**POST /databases/{id}/reset-password** — requires `{ new_password }` in the body. Connected apps will need their env vars updated. Confirm with the user first.

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/databases/DB_ID/reset-password",
  body: { new_password: "STRONG-PW-here" }
})).body
```

## 10. Web Terminal

**GET /applications/{id}/processes/{process_id}/terminal** — opens a WebSocket terminal into a running container. Supports `sh`, `bash`, `dash`, `ksh`, `zsh`, `csh`, `tcsh`. Files outside persistent storage paths are lost on redeploy.

When using the MCP server, this endpoint returns connection metadata — the actual shell session needs a WebSocket client. From `sevalla-api.sh` it is not directly usable; open it from the Sevalla dashboard.

## 11. Trigger Cron Job Manually

**POST /applications/{id}/processes/{process_id}/trigger** — runs a `cron` process now as a one-off, outside its schedule. No body.

## 12. Troubleshooting Triage

### Build failure

1. `GET /applications/{id}/deployments?limit=1` — confirm `status: "failed"`.
2. `GET /applications/{id}/deployments/{deployment_id}/logs` — read the build log.
3. Common causes: missing dependency, wrong runtime version, Dockerfile syntax, wrong `build_path` (see `references/deploy.md`).
4. Fix source, redeploy.

### Runtime crash / crash loop

1. Runtime logs (section 1) for stack traces.
2. `GET /applications/{id}/processes/{process_id}/metrics/exit-codes` to see how the process is dying.
3. Memory metrics (section 5) — near the limit ⇒ OOM. Increase pod size or fix the leak.
4. If the app dies before serving traffic, the liveness probe may be too aggressive — raise `initialDelaySeconds` or adjust the path (see `references/configure.md`).

### Slow responses

1. `metrics/response-time-avg` to confirm.
2. `metrics/slowest-requests` to find the bottleneck paths.
3. CPU metrics (section 5) — scale up or out if saturated (see `references/configure.md`).
4. DB CPU/memory (section 6) and slow query check if DB-bound.

### Database

1. `storage-usage` vs `storage-limit` — resize if near full.
2. CPU/memory metrics.
3. Verify automatic backups exist (section 7).
4. On corruption: restore from the latest backup — **confirm with the user**.

### 502 / 503

1. Verify the app isn't suspended (section 8); activate if needed.
2. Check readiness/liveness probe paths in `PATCH /applications/{id}/processes/{process_id}` (see `references/configure.md`).
3. Runtime logs for binding errors. The app **must** listen on `0.0.0.0:$PORT` — `$PORT` is injected by Sevalla.
4. If the app just deployed, the readiness probe may not have passed yet — wait or relax the probe.
