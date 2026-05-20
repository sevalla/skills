# Manage — API Keys, Webhooks, Load Balancers, Registries, Buckets, Usage Alerts

## 1. API Keys

API keys authenticate every request. Each key has roles and/or fine-grained capabilities, and an optional expiration.

| Action | Method | Path |
|---|---|---|
| List | GET | `/api-keys` |
| Create | POST | `/api-keys` |
| Get | GET | `/api-keys/{id}` |
| Update | PATCH | `/api-keys/{id}` |
| Delete | DELETE | `/api-keys/{id}` |
| Rotate | POST | `/api-keys/{id}/rotate` |
| Toggle (enable/disable) | POST | `/api-keys/{id}/toggle` |
| Validate current key | GET | `/api-keys/validate` |

### Create

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | yes | 1–255 chars |
| `role_ids` | string[] (uuid) | conditional | At least one of `role_ids` or `capabilities` |
| `capabilities` | `{ permission, id_resource? }[]` | conditional | `permission` format: `RESOURCE:ACTION` (e.g. `APP:READ`); `id_resource` scopes to one resource |
| `expired_at` | ISO 8601 (`...Z`) | no | Omit for no expiration |

List the available roles and permissions first:

```js
async () => ({
  roles: (await sevalla.request({ method: "GET", path: "/resources/rbac/api-key-roles" })).body,
  permissions: (await sevalla.request({ method: "GET", path: "/resources/rbac/api-key-permissions" })).body
})
```

Create a CI deploy key with a specific role:

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/api-keys",
    body: {
      name: "ci-deploy-key",
      role_ids: ["ROLE_UUID"],
      expired_at: "2026-12-31T23:59:59Z"
    }
  })
  return res.body
}
```

Or with granular capabilities (scope to a single app):

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/api-keys",
    body: {
      name: "ci-deploy-key",
      capabilities: [{ permission: "APP:DEPLOY", id_resource: "APP_ID" }]
    }
  })
  return res.body
}
```

**The token value is returned only once on create.** Store it immediately.

### Rotate

**POST /api-keys/{id}/rotate** — generates a new token. Pass `{ "old_token_ttl_hours": N }` (0–168) to keep the old token valid during a grace window. Default is 0 (immediate invalidation).

### Validate

`GET /api-keys/validate` — checks whether the *calling* key is active. Useful for bootstrap scripts.

## 2. Webhooks

Outbound HTTP notifications for platform events. Each delivery is signed with a secret.

| Action | Method | Path |
|---|---|---|
| List | GET | `/webhooks` |
| Create | POST | `/webhooks` |
| Get | GET | `/webhooks/{id}` |
| Update | PATCH | `/webhooks/{id}` |
| Delete | DELETE | `/webhooks/{id}` |
| Roll secret | POST | `/webhooks/{id}/roll-secret` |
| Toggle | POST | `/webhooks/{id}/toggle` |
| List deliveries | GET | `/webhooks/{id}/deliveries` |
| Get delivery | GET | `/webhooks/{id}/deliveries/{delivery_id}` |

### Create

| Field | Type | Required | Notes |
|---|---|---|---|
| `endpoint` | string (uri) | yes | HTTPS receiver |
| `allowed_events` | string[] | yes | At least one — see below |
| `description` | string | no | Max 255 chars |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/webhooks",
    body: {
      endpoint: "https://example.com/sevalla-webhook",
      allowed_events: ["APP_DEPLOY", "DATABASE_UPDATE"],
      description: "Production deploy notifications"
    }
  })
  return res.body
}
```

### Events

`APP_CREATE`, `APP_UPDATE`, `APP_DELETE`, `APP_DEPLOY`, `DATABASE_CREATE`, `DATABASE_UPDATE`, `DATABASE_DELETE`, `STATIC_SITE_CREATE`, `STATIC_SITE_UPDATE`, `STATIC_SITE_DELETE`, `STATIC_SITE_DEPLOY`.

### Roll secret

**POST /webhooks/{id}/roll-secret** — body `{ "expire_in_hours": 0..24 }` (default 0). Both secrets are valid during the transition window, so existing receivers can rotate without downtime.

### Deliveries

Each delivery record includes the response status code, request payload, response body, and timestamps. Use this to debug failed notifications.

## 3. Load Balancers

Route traffic across multiple backends.

| Action | Method | Path | Body |
|---|---|---|---|
| Create | POST | `/load-balancers` | `{ display_name, type?, project_id? }` |
| List | GET | `/load-balancers` | — |
| Get | GET | `/load-balancers/{id}` | — |
| Update | PATCH | `/load-balancers/{id}` | partial |
| Delete | DELETE | `/load-balancers/{id}` | — |

Only `display_name` is required. `type` is `"DEFAULT"` (round-robin / weighted) or `"GEO"` (geographic routing).

### Destinations (backends)

| Action | Method | Path |
|---|---|---|
| Add | POST | `/load-balancers/{id}/destinations` |
| List | GET | `/load-balancers/{id}/destinations` |
| Remove | DELETE | `/load-balancers/{id}/destinations/{destination_id}` |
| Toggle | POST | `/load-balancers/{id}/destinations/{destination_id}/toggle` |

**POST body:**

| Field | Type | Required | Notes |
|---|---|---|---|
| `service_type` | string | yes | `APP`, `STATIC_SITE`, `OBJECT_STORAGE`, `EXTERNAL`, `LOAD_BALANCER` (UPPERCASE) |
| `service_id` | string | conditional | Required for APP / STATIC_SITE / OBJECT_STORAGE / LOAD_BALANCER |
| `url` | string | conditional | Required for EXTERNAL |
| `weight` | integer | no | 0–10000 (weighted routing) |
| `latitude` / `longitude` | number | conditional | Required for `GEO` LBs |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/load-balancers/LB_ID/destinations",
    body: { service_type: "APP", service_id: "APP_ID", weight: 100 }
  })
  return res.body
}
```

### Domains

Load balancers support custom domains at `/load-balancers/{id}/domains` — same shape as application domains (use `domain_name`). See `references/configure.md`.

## 4. Docker Registries

Store credentials for private container registries.

| Action | Method | Path |
|---|---|---|
| Create | POST | `/docker-registries` |
| List | GET | `/docker-registries` |
| Get | GET | `/docker-registries/{id}` |
| Update | PATCH | `/docker-registries/{id}` |
| Delete | DELETE | `/docker-registries/{id}` |

**POST body:** `{ name, registry, username, password }`.

| `registry` value | Provider |
|---|---|
| `dockerHub` | Docker Hub |
| `gcr` | Google Container Registry |
| `ecr` | AWS ECR |
| `github` | GitHub Container Registry |
| `gitlab` | GitLab Container Registry |
| `digitalOcean` | DigitalOcean Container Registry |
| `custom` | Custom registry |

Reference the registry ID via `docker_registry_credential_id` when creating or updating an application.

## 5. Resource Catalogs

Read-only data — use these to discover valid IDs.

| Endpoint | Returns |
|---|---|
| `GET /resources/clusters` | All regions with IDs |
| `GET /resources/process-resource-types` | Pod sizes |
| `GET /resources/database-resource-types` | DB sizes |
| `GET /resources/rbac/api-key-roles` | Roles available for API keys |
| `GET /resources/rbac/api-key-permissions` | Granular capabilities |
| `GET /git/providers` | Connected GitHub / GitLab / Bitbucket installations |

## 6. Users

**GET /users** — lists company members with IDs, names, emails, and roles.

## 7. Object Storage — Advanced

Bucket creation is in `references/setup.md`. This section covers post-creation management.

### CORS policies

| Action | Method | Path |
|---|---|---|
| List | GET | `/object-storage/{id}/cors-policies` |
| Create | POST | `/object-storage/{id}/cors-policies` |
| Update | PATCH | `/object-storage/{id}/cors-policies/{cors_policy_id}` |
| Delete | DELETE | `/object-storage/{id}/cors-policies/{cors_policy_id}` |

**POST body** (field names matter):

| Field | Type | Required | Notes |
|---|---|---|---|
| `methods` | string[] | yes | Any of `GET`, `PUT`, `POST`, `DELETE`, `HEAD` |
| `origins` | string[] | yes | Up to 100; use `["*"]` for any origin |
| `headers` | string[] | no | Up to 100 |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/object-storage/BUCKET_ID/cors-policies",
    body: {
      methods: ["GET", "PUT"],
      origins: ["https://example.com"],
      headers: ["Content-Type"]
    }
  })
  return res.body
}
```

### CDN domain

`POST /object-storage/{id}/domain` — enable a CDN-backed public domain for the bucket. `DELETE` disables it.

### Rotate credentials

**POST /object-storage/{id}/rotate-credentials** — body `{ "old_keys_ttl_hours": 0..168 }` (default 0). Keep the previous access/secret key pair valid during the transition window so clients can migrate without downtime. Confirm with the user before invalidating immediately.

### Objects

| Action | Method | Path |
|---|---|---|
| List | GET | `/object-storage/{id}/objects` |
| Bulk delete | DELETE | `/object-storage/{id}/objects` |

**List query params:** `prefix`, `delimiter` (use `"/"` for directory-style), `cursor`, `limit` (default 200).

**Bulk delete body:** `{ "keys": ["images/photo.jpg", "docs/readme.txt"] }`. Max 1000 keys per request. **Confirm with the user before bulk deletion.**

## 8. Usage Alerts

Spending notifications by company or per project.

| Action | Method | Path |
|---|---|---|
| List | GET | `/usage-alerts` |
| Create | POST | `/usage-alerts` |
| Get | GET | `/usage-alerts/{id}` |
| Update | PATCH | `/usage-alerts/{id}` |
| Delete | DELETE | `/usage-alerts/{id}` |

**POST body:**

| Field | Type | Required | Notes |
|---|---|---|---|
| `limit_usd` | number | yes | Spending limit in USD |
| `emails` | string[] | yes | At least one recipient |
| `triggers` | `{ percentage }[]` | yes | 1–10 entries; percentages 1–100 |
| `project_id` | string (uuid) \| null | no | Scope to a project; null/omit = company-wide |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/usage-alerts",
    body: {
      limit_usd: 100,
      emails: ["billing@example.com"],
      triggers: [{ percentage: 50 }, { percentage: 80 }, { percentage: 100 }]
    }
  })
  return res.body
}
```

## 9. Device Authorization (Headless Auth)

OAuth device flow for CLIs and headless tools. **No authentication required** for these endpoints.

| Action | Method | Path |
|---|---|---|
| Start | POST | `/auth/device-codes` |
| Poll | GET | `/auth/device-codes/{code}` |

Flow:

1. POST `/auth/device-codes` → returns `code` and a `verification_url`.
2. Open the URL in a browser and approve.
3. Poll GET `/auth/device-codes/{code}` until status flips from `pending` to `approved`.
4. On approval, the response includes an API token.
