# Operations & Troubleshooting Reference

This reference covers monitoring, logs, metrics, backups, and troubleshooting for applications, databases, and static sites on Sevalla.

## 1. Runtime Logs

Application stdout/stderr output. Use this to see application-level log messages, errors, and debug output.

**GET /applications/{id}/runtime-logs**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/runtime-logs" })
  return res.body
}
```

Returns log entries with timestamps. Each entry includes the process name, log level, and message content.

## 2. Access Logs

HTTP request logs showing incoming traffic to the application. Each entry includes the HTTP method, request path, status code, and response time.

**GET /applications/{id}/access-logs**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/access-logs" })
  return res.body
}
```

Use access logs to identify 4xx/5xx error patterns, slow endpoints, and traffic volume.

## 3. Deployment Logs

Build-time logs showing each step of the build process. Useful for diagnosing build failures.

**GET /applications/{id}/deployments/{deployment_id}/logs**

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/deployments/DEPLOYMENT_ID/logs" })
  return res.body
}
```

To find the deployment ID, fetch the latest deployment first:

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/deployments", query: { limit: 1 } })
  return res.body
}
```

## 4. Application Metrics

Eight metric endpoints provide traffic and performance data for applications.

| Endpoint | What it shows |
|---|---|
| GET /applications/{id}/metrics/requests-per-minute | Request rate |
| GET /applications/{id}/metrics/response-time | Response time distribution |
| GET /applications/{id}/metrics/response-time-avg | Average response time |
| GET /applications/{id}/metrics/slowest-requests | Slowest request paths |
| GET /applications/{id}/metrics/status-codes | HTTP status code breakdown |
| GET /applications/{id}/metrics/top-status-codes | Most frequent status codes |
| GET /applications/{id}/metrics/top-countries | Traffic by country |
| GET /applications/{id}/metrics/top-pages | Most visited pages |

### Check request rate

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/metrics/requests-per-minute" })
  return res.body
}
```

### Check average response time

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/metrics/response-time-avg" })
  return res.body
}
```

### Check status code breakdown

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/metrics/status-codes" })
  return res.body
}
```

## 5. Process Metrics

Per-process resource usage metrics. Requires both the application ID and the process ID.

| Endpoint | What it shows |
|---|---|
| GET /applications/{id}/processes/{process_id}/metrics/cpu-usage | CPU usage (millicores) |
| GET /applications/{id}/processes/{process_id}/metrics/cpu-limit | CPU limit |
| GET /applications/{id}/processes/{process_id}/metrics/memory-usage | Memory usage (MB) |
| GET /applications/{id}/processes/{process_id}/metrics/memory-limit | Memory limit |
| GET /applications/{id}/processes/{process_id}/metrics/instance-count | Running instances |

### Check CPU and memory together

```js
async () => {
  const [cpu, cpuLimit, mem, memLimit] = await Promise.all([
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/cpu-usage" }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/cpu-limit" }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/memory-usage" }),
    sevalla.request({ method: "GET", path: "/applications/APP_ID/processes/PROCESS_ID/metrics/memory-limit" })
  ])
  return { cpu: cpu.body, cpuLimit: cpuLimit.body, memory: mem.body, memoryLimit: memLimit.body }
}
```

## 6. Database Metrics

Resource usage metrics for managed database instances.

| Endpoint | What it shows |
|---|---|
| GET /databases/{id}/metrics/cpu-usage | CPU usage |
| GET /databases/{id}/metrics/cpu-limit | CPU limit |
| GET /databases/{id}/metrics/memory-usage | Memory usage |
| GET /databases/{id}/metrics/memory-limit | Memory limit |
| GET /databases/{id}/metrics/storage-usage | Storage used |
| GET /databases/{id}/metrics/storage-limit | Storage limit |

```js
async () => {
  const [storageUsed, storageLimit] = await Promise.all([
    sevalla.request({ method: "GET", path: "/databases/DB_ID/metrics/storage-usage" }),
    sevalla.request({ method: "GET", path: "/databases/DB_ID/metrics/storage-limit" })
  ])
  return { storageUsed: storageUsed.body, storageLimit: storageLimit.body }
}
```

## 7. Database Backups

Sevalla provides automatic daily backups (7-day retention) and manual backups (14-day retention, max 5 per database).

| Operation | Method | Endpoint |
|---|---|---|
| List backups | GET | /databases/{id}/backups |
| Create manual backup | POST | /databases/{id}/backups |
| Restore from backup | POST | /databases/{id}/backups/{backup_id}/restore |
| Delete backup | DELETE | /databases/{id}/backups/{backup_id} |

### List backups

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/databases/DB_ID/backups" })
  return res.body
}
```

### Create a manual backup

```js
async () => {
  const res = await sevalla.request({ method: "POST", path: "/databases/DB_ID/backups", body: {} })
  return res.body
}
```

### Restore from backup

**DESTRUCTIVE: Always confirm with the user before restoring.** This overwrites the current database contents with the backup data.

```js
async () => {
  const res = await sevalla.request({ method: "POST", path: "/databases/DB_ID/backups/BACKUP_ID/restore", body: {} })
  return res.body
}
```

### Delete a backup

```js
async () => {
  const res = await sevalla.request({ method: "DELETE", path: "/databases/DB_ID/backups/BACKUP_ID" })
  return res.body
}
```

## 8. Suspend & Activate

Stop all processes to save costs when a service is not in use.

| Operation | Method | Endpoint |
|---|---|---|
| Suspend application | POST | /applications/{id}/suspend |
| Activate application | POST | /applications/{id}/activate |
| Suspend database | POST | /databases/{id}/suspend |
| Activate database | POST | /databases/{id}/activate |

**Always confirm suspend/activate with the user.** Suspending stops all running processes and makes the service unavailable. Activating restarts the service.

```js
async () => {
  const res = await sevalla.request({ method: "POST", path: "/applications/APP_ID/suspend", body: {} })
  return res.body
}
```

## 9. Web Terminal

Opens a WebSocket terminal session to a running process container.

**GET /applications/{id}/processes/{process_id}/terminal**

Supports `sh`, `bash`, and `zsh` shells. The terminal connects directly to the running container.

**Important:** Files created outside persistent storage paths are lost on redeployment. Use persistent storage for any data that must survive deployments.

## 10. Trigger Cron Job

Manually trigger a cron job process outside its regular schedule.

**POST /applications/{id}/processes/{process_id}/trigger**

```js
async () => {
  const res = await sevalla.request({ method: "POST", path: "/applications/APP_ID/processes/PROCESS_ID/trigger", body: {} })
  return res.body
}
```

The process must be of type `cron`. This runs the job immediately as a one-off execution.

## 11. Static Site Metrics

Static sites support the same 8 metric endpoints as applications, under the `/static-sites/{id}/metrics/` path.

| Endpoint | What it shows |
|---|---|
| GET /static-sites/{id}/metrics/requests-per-minute | Request rate |
| GET /static-sites/{id}/metrics/response-time | Response time distribution |
| GET /static-sites/{id}/metrics/response-time-avg | Average response time |
| GET /static-sites/{id}/metrics/slowest-requests | Slowest request paths |
| GET /static-sites/{id}/metrics/status-codes | HTTP status code breakdown |
| GET /static-sites/{id}/metrics/top-status-codes | Most frequent status codes |
| GET /static-sites/{id}/metrics/top-countries | Traffic by country |
| GET /static-sites/{id}/metrics/top-pages | Most visited pages |

## 12. Troubleshooting Triage

### Build failures

1. Get the latest deployment: `GET /applications/{id}/deployments?limit=1`
2. Check the deployment `status` field — if `"failed"`, fetch deployment logs (section 3).
3. Common causes: missing dependencies in `package.json` or `requirements.txt`, wrong runtime version, Dockerfile syntax errors, incorrect build command.
4. Fix the source code and redeploy (see `references/deploy.md`).

### Runtime crashes

1. Check runtime logs (section 1) for error messages and stack traces.
2. Check process metrics (section 5) — high memory usage near the limit indicates a possible OOM kill.
3. If OOM: increase the pod size (see `references/configure.md`) or fix the memory leak in application code.
4. If crash loop: check liveness probe settings — the probe may be failing before the app finishes starting. Increase the `initial_delay_seconds` or adjust the probe path.

### Slow responses

1. Check the `response-time-avg` metric (section 4) to confirm the problem.
2. Check `slowest-requests` to identify which paths are bottlenecks.
3. Check CPU usage (section 5) — if near the limit, scale up the pod size or add replicas (see `references/configure.md`).
4. Check database metrics (section 6) if the application is database-heavy — slow queries or high DB CPU can cause slow responses.

### Database issues

1. Check `storage-usage` vs `storage-limit` — if near the limit, resize the database (see `references/configure.md`).
2. Check CPU and memory metrics for the database (section 6).
3. List backups (section 7) — verify automatic daily backups are running as expected.
4. If data is corrupted: restore from the latest backup (section 7). **Always confirm with the user before restoring.**

### 502/503 errors

1. Check if the application is deployed and running — it may be suspended (section 8). Activate it if needed.
2. Check health check configuration — readiness and liveness probes may be misconfigured (see `references/configure.md`).
3. Check runtime logs (section 1) for startup failures or binding errors.
4. Verify the application listens on the correct `PORT` environment variable. Sevalla injects `PORT` automatically; the app must bind to `0.0.0.0:$PORT`.
