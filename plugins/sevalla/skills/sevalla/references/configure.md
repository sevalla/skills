# Configure — Environment, Domains, Scaling, Networking

Reference for changing configuration on Sevalla-hosted resources. Covers environment variables, custom domains, scaling, internal networking, TCP proxies, private ports, IP restrictions, CDN, health checks, and processes.

## Environment Variables

Application-scoped environment variables control runtime and build behavior.

### List Environment Variables

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/applications/APP_ID/env-vars" })
  return res.body
}
```

### Create an Environment Variable

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/env-vars",
    body: { key: "DATABASE_URL", value: "postgres://user:pass@host:5432/db", is_runtime: true, is_buildtime: false }
  })
  return res.body
}
```

### Update an Environment Variable

```
PUT /applications/{id}/env-vars/{env_var_id}
```

Body: `{ key, value, is_runtime, is_buildtime }`

### Delete an Environment Variable

```
DELETE /applications/{id}/env-vars/{env_var_id}
```

### Rules

- **Allowed characters in keys**: lowercase and uppercase letters (`a-z`, `A-Z`), digits (`0-9`), and underscore (`_`). No hyphens, spaces, or special characters.
- **Variable referencing**: use `${KEY}` syntax inside a value to reference another variable. Example: `DATABASE_URL` set to `postgres://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/mydb`.
- **Scoping**: `is_runtime: true` makes the variable available to the running process. `is_buildtime: true` makes it available during the build step. A variable can be both runtime and buildtime.
- **Redeploy required**: changes to environment variables do not take effect until the application is redeployed.

### Static Site Environment Variables

Static sites use the same endpoints at a different base path:

```
GET    /static-sites/{id}/env-vars
POST   /static-sites/{id}/env-vars
PUT    /static-sites/{id}/env-vars/{env_var_id}
DELETE /static-sites/{id}/env-vars/{env_var_id}
```

Request and response schemas are identical to application env vars.

## Sevalla-Injected Variables

Sevalla automatically injects the following variables into every process. These are read-only and always available at runtime without any configuration.

| Variable | Description |
|---|---|
| `SVL_COMPANY_ID` | Company identifier |
| `SVL_APP_ID` | Application identifier |
| `SVL_APP_NAME` | Application name |
| `SVL_PROCESS_ID` | Process identifier |
| `SVL_PROCESS_TYPE` | Process type (`web`, `worker`, `cron`, `job`) |
| `SVL_DEPLOYMENT_ID` | Current deployment identifier |
| `SVL_DEPLOYMENT_INITIATED_BY` | Who triggered the deployment (username or "system") |
| `SVL_DEPLOYMENT_TRIGGER` | What triggered the deployment (e.g., "manual", "git_push", "api") |
| `SVL_DEPLOYMENT_COMMIT_SHA` | Git commit SHA of the deployed code |
| `SVL_DEPLOYMENT_BRANCH` | Git branch that was deployed |
| `SVL_DEPLOYMENT_DOCKER_IMAGE` | Docker image URL for the deployment |
| `PORT` | Port the process should listen on (default `8080`) |

Use these in application code to determine the current execution context. For example, check `SVL_PROCESS_TYPE` to run different logic in web vs. worker processes.

## Global Environment Variables

Company-wide variables that are automatically deployed to all applications under the company.

```
GET    /applications/global-env-vars
POST   /applications/global-env-vars          — body: { key, value }
PUT    /applications/global-env-vars/{id}     — body: { key, value }
DELETE /applications/global-env-vars/{id}
```

Global variables are overridden by application-scoped variables with the same key. Use global variables for shared configuration like logging endpoints or feature flags that apply across all services.

## Custom Domains

### List Domains

```
GET /applications/{id}/domains
```

### Add a Domain

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/domains",
    body: { name: "example.com" }
  })
  return res.body
}
```

### Delete a Domain

```
DELETE /applications/{id}/domains/{domain_id}
```

### Set Primary Domain

```
POST /applications/{id}/domains/{domain_id}/set-primary
```

### Refresh Verification Status

```
POST /applications/{id}/domains/{domain_id}/refresh-status
```

### Toggle System Domain

Enable or disable the default `*.svl.app` system domain:

```
POST /applications/{id}/domains/{domain_id}/toggle
```

### DNS Setup Steps

After adding a custom domain, the API response includes DNS records that must be configured at your DNS provider:

1. **TXT record** for domain ownership: set `_cf-custom-hostname.yourdomain.com` to the value from the API response.
2. **CNAME record** for SSL validation: set `_acme-challenge.yourdomain.com` to the value from the API response.
3. **A records** pointing your domain to Sevalla's IP addresses (provided in the API response).
4. **Wait for verification**: the domain status progresses through `VERIFICATION` (DNS records not yet detected) then `VERIFIED` (DNS confirmed, SSL provisioning) then `POINTING` (fully active and serving traffic).

Propagation can take up to 48 hours depending on DNS TTL settings.

### Wildcard Domains

To add a wildcard domain (`*.yourdomain.com`), set `is_wildcard: true` in the request body:

```json
{ "name": "yourdomain.com", "is_wildcard": true }
```

### SSL Certificates

Free SSL certificates are provisioned automatically via Cloudflare. No manual certificate management is required.

**Important**: Custom domains require upgrading from the Hobby pod size. Applications on the Hobby tier can only use the default system domain.

### Domains for Other Resource Types

The same domain management pattern applies to static sites and load balancers:

```
/static-sites/{id}/domains
/load-balancers/{id}/domains
```

All sub-endpoints (`set-primary`, `refresh-status`, `toggle`) are available on both resource types.

## Scaling

### Vertical Scaling — Change Pod Size

Upgrade or downgrade the compute resources for a process:

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

Discover available sizes with:

```
GET /resources/process-resource-types
```

### Pod Size Categories

| Category | Examples | Use case |
|---|---|---|
| Hobby | -- | Development, testing |
| Standard | S1, S2 | General workloads |
| Memory-Optimized | M1, M2, M3 | Caching, data processing |
| CPU-Optimized | C1, C2, C3 | Compute-heavy tasks |

### Horizontal Scaling (Manual)

Set a fixed number of instances for a process:

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID/processes/PROCESS_ID",
    body: { scaling_strategy: { type: "manual", instanceCount: 3 } }
  })
  return res.body
}
```

Maximum 20 instances per process. Available for `web` and `worker` process types only.

### Horizontal Scaling (Auto)

Auto-scale based on CPU utilization:

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID/processes/PROCESS_ID",
    body: {
      scaling_strategy: {
        type: "horizontal",
        minInstanceCount: 1,
        maxInstanceCount: 10,
        targetCpuPercent: 80
      }
    }
  })
  return res.body
}
```

Sevalla will add or remove instances to keep average CPU usage near the target percentage.

**Constraint**: Processes with persistent storage attached are limited to 1 instance. Horizontal scaling (manual or auto) is not available for these processes. Detach the persistent storage first if scaling is required.

## Internal Networking

Connect applications to databases over the private network within the same region. Internal connections use private IPs, incur no bandwidth charges, and have lower latency than public connections.

### List Internal Connections

```
GET /databases/{id}/internal-connections
```

### Create an Internal Connection

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/databases/DB_ID/internal-connections",
    body: { app_id: "APP_ID" }
  })
  return res.body
}
```

### Delete an Internal Connection

```
DELETE /databases/{id}/internal-connections/{connection_id}
```

After creating an internal connection, set the internal hostname and port as environment variables on the application. The internal hostname is returned in the connection response. Both the application and the database must be in the same data center region.

### Toggle External Database Connection

Enable or disable public internet access to a database (useful for connecting from local development tools, running migrations, or external monitoring):

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/databases/DB_ID/external-connection/toggle"
  })
  return res.body
}
```

When external connections are enabled, the database becomes accessible via its `external_hostname` and `external_port`. Disable external connections when not needed to reduce attack surface.

## TCP Proxies

Expose non-HTTP services to the internet. Use TCP proxies for protocols like WebSocket, MongoDB, RabbitMQ, or any custom TCP protocol.

```
GET    /applications/{id}/tcp-proxies
POST   /applications/{id}/tcp-proxies        — body: { port: 27017 }
DELETE /applications/{id}/tcp-proxies/{tcp_proxy_id}
```

Maximum 3 TCP proxies per application. Each proxy is assigned a unique external port that maps to the specified internal port.

## Private Ports

Internal-only ports for service-to-service communication within the Sevalla network. Private ports are not exposed to the public internet.

```
GET    /applications/{id}/private-ports
POST   /applications/{id}/private-ports       — body: { port: 9090 }
DELETE /applications/{id}/private-ports/{private_port_id}
```

Use private ports when one application needs to call another over an internal protocol (gRPC, custom TCP) without public exposure.

## IP Restrictions

Control access to applications and databases by allowlisting or denylisting IP addresses.

### Get Current Restrictions

```
GET /applications/{id}/ip-restriction
```

### Update IP Restrictions

```js
async () => {
  const res = await sevalla.request({
    method: "PUT",
    path: "/applications/APP_ID/ip-restriction",
    body: {
      type: "allow",
      is_enabled: true,
      ip_list: ["1.2.3.4", "10.0.0.0/8"]
    }
  })
  return res.body
}
```

- `type: "allow"` — only the listed IPs can access the resource (allowlist).
- `type: "deny"` — the listed IPs are blocked; all others can access (denylist).
- `is_enabled: false` — disables IP restrictions without removing the configuration.
- CIDR notation is supported (e.g., `10.0.0.0/8`).

Database IP restrictions use the same schema at `/databases/{id}/ip-restriction`.

## CDN & Edge Cache

### Toggle CDN

Enable or disable CDN caching for an application:

```
POST /applications/{id}/cdn/toggle
```

### Purge Edge Cache

Clear the server-side edge cache and CDN cache:

```
POST /applications/{id}/purge-cache
```

This purges both the application edge cache and the CDN cache in a single call.

## Health Checks

Configure readiness and liveness probes on processes via:

```
PATCH /applications/{id}/processes/{process_id}
```

### Readiness Probe

Determines whether a process is ready to receive traffic. New instances are not added to the load balancer until the readiness probe passes.

```json
{
  "readiness_probe": {
    "httpGet": { "path": "/health", "port": 8080 },
    "initialDelaySeconds": 10,
    "periodSeconds": 10,
    "timeoutSeconds": 5,
    "failureThreshold": 3
  }
}
```

### Liveness Probe

Determines whether a process is still alive. If the liveness probe fails, the container is restarted automatically.

```json
{
  "liveness_probe": {
    "tcpSocket": { "port": 8080 },
    "initialDelaySeconds": 30,
    "periodSeconds": 30,
    "timeoutSeconds": 5,
    "failureThreshold": 3
  }
}
```

### Probe Types

| Type | Config | Use case |
|---|---|---|
| `httpGet` | `{ path, port }` | HTTP endpoints returning 200-399 |
| `tcpSocket` | `{ port }` | Check if a port is accepting connections |
| `exec` | `{ command: ["cmd", "arg1"] }` | Run a custom command; exit code 0 = healthy |

## Processes

Processes define the runtime units within an application.

### List Processes

```
GET /applications/{id}/processes
```

### Create a Process

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/processes",
    body: {
      display_name: "background-worker",
      type: "worker",
      entrypoint: "node worker.js",
      port: 8080,
      resource_type_id: "S1"
    }
  })
  return res.body
}
```

### Update a Process

```
PATCH /applications/{id}/processes/{process_id}
```

### Delete a Process

```
DELETE /applications/{id}/processes/{process_id}
```

### Process Types

| Type | Purpose | Internet-accessible | Max instances |
|---|---|---|---|
| `web` | HTTP traffic | Yes | 20 |
| `worker` | Background processing | No | 20 |
| `cron` | Scheduled execution | No | 1 |
| `job` | One-off runs (pre/post deploy) | No | 1 |

**Cron processes**: set `schedule` to a 5-field cron expression (e.g., `"*/5 * * * *"` for every 5 minutes) and `time_zone` to an IANA time zone identifier (e.g., `"America/New_York"`).

**Job processes**: set `job_start_policy` to control when the job runs relative to deployments:
- `"beforeDeployment"` — runs before the new version is deployed.
- `"afterSuccessDeployment"` — runs after a successful deployment.
- `"afterFailedDeployment"` — runs after a failed deployment (for cleanup or notifications).

## Troubleshoot Configuration

| Problem | Cause | Resolution |
|---|---|---|
| Domain stuck in `VERIFICATION` | DNS records not detected | Verify TXT and CNAME records are correct. Wait up to 48 hours for propagation. Use `refresh-status` endpoint to re-check. |
| SSL certificate not issuing | CAA record conflict | Check for CAA DNS records that restrict certificate authorities. Remove or add Cloudflare's CA to the allowed list. |
| Cannot scale horizontally | Persistent storage attached | Processes with persistent storage are limited to 1 instance. Detach persistent storage before enabling horizontal scaling. |
| Env var not taking effect | Missing redeploy | Environment variable changes require a redeployment. Trigger a new deployment after updating env vars. |
| Internal connection failing | Region mismatch | The application and database must be in the same data center region. Check both resources and migrate if needed. |
| IP restriction blocking legitimate traffic | Incorrect CIDR range | Review the `ip_list` entries. Ensure CIDR notation covers all required source IPs. Disable temporarily with `is_enabled: false` to verify. |
