# Manage — Platform Resources & Administration

Reference for managing API keys, webhooks, load balancers, Docker registries, object storage policies, users, and device authorization on Sevalla.

---

## 1. API Keys

Manage authentication tokens used to access the Sevalla API. Each key has a name, one or more roles, a set of capabilities, and an optional expiration date.

**Sources:** `DASHBOARD` (created in the UI), `CLI` (created via the CLI), `EXTERNAL` (created via the API).

| Action | Method | Path |
|---|---|---|
| List | **GET** | `/api-keys` |
| Create | **POST** | `/api-keys` |
| Get | **GET** | `/api-keys/{id}` |
| Update | **PATCH** | `/api-keys/{id}` |
| Delete | **DELETE** | `/api-keys/{id}` |
| Rotate | **POST** | `/api-keys/{id}/rotate` |
| Toggle | **POST** | `/api-keys/{id}/toggle` |
| Validate | **GET** | `/api-keys/validate` |

**POST /api-keys** body:

| Field | Type | Required | Description |
|---|---|---|---|
| name | string | yes | Human-readable key name |
| roles | string[] | yes | Roles assigned to the key |
| capabilities | string[] | no | Fine-grained permissions |
| expired_at | string | no | ISO 8601 expiration timestamp |

**Rotate** generates a new token value. The old token remains valid for a grace period so in-flight requests are not interrupted.

**Toggle** enables or disables a key without deleting it. Disabled keys return 401 on any request.

**Validate** checks whether a key is valid. This endpoint does not require authentication — pass the key as a Bearer token and the response indicates whether it is active.

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/api-keys", query: { limit: 100 } })
  return res.body
}
```

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/api-keys",
    body: {
      name: "ci-deploy-key",
      roles: ["deploy"],
      capabilities: ["deployments:write"],
      expired_at: "2026-12-31T23:59:59Z"
    }
  })
  return res.body
}
```

**Important:** The token value is only returned once in the create response. Store it immediately — it cannot be retrieved later.

---

## 2. Webhooks

Real-time HTTP notifications for platform events. Sevalla sends a POST request to your endpoint whenever a subscribed event occurs. Each delivery is signed with a secret so you can verify authenticity.

| Action | Method | Path |
|---|---|---|
| List | **GET** | `/webhooks` |
| Create | **POST** | `/webhooks` |
| Get | **GET** | `/webhooks/{id}` |
| Update | **PATCH** | `/webhooks/{id}` |
| Delete | **DELETE** | `/webhooks/{id}` |
| Roll secret | **POST** | `/webhooks/{id}/roll-secret` |
| Toggle | **POST** | `/webhooks/{id}/toggle` |

**POST /webhooks** body:

| Field | Type | Required | Description |
|---|---|---|---|
| endpoint | string | yes | HTTPS URL to receive events |
| description | string | no | Human-readable description |
| allowed_events | string[] | yes | Events to subscribe to (see table below) |
| is_enabled | boolean | no | Whether the webhook is active (default true) |

### Available events

| Event | Fires when |
|---|---|
| APP_CREATE | Application created |
| APP_UPDATE | Application updated |
| APP_DELETE | Application deleted |
| APP_DEPLOY | Deployment completed |
| DATABASE_CREATE | Database created |
| DATABASE_UPDATE | Database updated |
| DATABASE_DELETE | Database deleted |
| STATIC_SITE_CREATE | Static site created |
| STATIC_SITE_UPDATE | Static site updated |
| STATIC_SITE_DELETE | Static site deleted |
| STATIC_SITE_DEPLOY | Static site deployment completed |

**Roll secret** rotates the signing secret used to verify webhook deliveries. The old secret remains valid for a grace period so your receiver can accept payloads signed with either secret during the transition.

### Webhook deliveries

Inspect delivery history for debugging failed or missed notifications.

| Action | Method | Path |
|---|---|---|
| List deliveries | **GET** | `/webhooks/{id}/deliveries` |
| Get delivery | **GET** | `/webhooks/{id}/deliveries/{delivery_id}` |

Each delivery record includes the HTTP status code returned by your endpoint, the request payload, response body, and timestamps.

---

## 3. Load Balancers

Route traffic across multiple application backends with configurable weights. Use load balancers for blue-green deployments, A/B testing, or distributing traffic across regional instances.

### Load balancer CRUD

| Action | Method | Path |
|---|---|---|
| Create | **POST** | `/load-balancers` |
| List | **GET** | `/load-balancers` |
| Get | **GET** | `/load-balancers/{id}` |
| Update | **PATCH** | `/load-balancers/{id}` |
| Delete | **DELETE** | `/load-balancers/{id}` |

**POST /load-balancers** body:

| Field | Type | Required | Description |
|---|---|---|---|
| company_id | string | yes | Company identifier |
| project_id | string | yes | Project identifier |
| display_name | string | yes | Load balancer name |

### Destinations (backend apps)

Destinations define which applications receive traffic and how much.

| Action | Method | Path |
|---|---|---|
| Add | **POST** | `/load-balancers/{id}/destinations` |
| List | **GET** | `/load-balancers/{id}/destinations` |
| Remove | **DELETE** | `/load-balancers/{id}/destinations/{destination_id}` |
| Toggle | **POST** | `/load-balancers/{id}/destinations/{destination_id}/toggle` |

**POST /load-balancers/{id}/destinations** body:

| Field | Type | Required | Description |
|---|---|---|---|
| app_id | string | yes | Application to route traffic to |
| weight | integer | yes | Relative traffic weight (higher = more traffic) |

### Domains

Load balancers support custom domains using the same pattern as applications. Manage them at `/load-balancers/{id}/domains` with the standard domain operations (list, add, remove, verify).

---

## 4. Docker Registries

Store credentials for private container registries so Sevalla can pull Docker images during deployment.

| Action | Method | Path |
|---|---|---|
| Create | **POST** | `/docker-registries` |
| List | **GET** | `/docker-registries` |
| Get | **GET** | `/docker-registries/{id}` |
| Update | **PATCH** | `/docker-registries/{id}` |
| Delete | **DELETE** | `/docker-registries/{id}` |

**POST /docker-registries** body:

| Field | Type | Required | Description |
|---|---|---|---|
| name | string | yes | Display name for the registry |
| registry | string | yes | Registry type (see table below) |
| username | string | yes | Authentication username |
| password | string | yes | Authentication password or access token |

### Registry types

| Registry | Value |
|---|---|
| Docker Hub | `dockerHub` |
| Google Container Registry | `gcr` |
| AWS ECR | `ecr` |
| GitHub Container Registry | `github` |
| GitLab Container Registry | `gitlab` |
| DigitalOcean Container Registry | `digitalOcean` |
| Custom Registry | `custom` |

After creating a registry, reference it when creating or updating applications that deploy from Docker images. The registry credentials are used automatically during image pulls.

---

## 5. Available Resources (Reference Data)

Read-only endpoints for discovering platform capabilities. Use these to look up valid IDs before creating resources.

### Clusters (regions)

**GET /resources/clusters** — Returns all 25 GCP data center regions with their IDs, display names, and geographic locations.

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/clusters" })
  return res.body
}
```

### Process sizes

**GET /resources/process-resource-types** — Returns all available pod sizes with CPU cores, memory, and pricing.

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/process-resource-types" })
  return res.body
}
```

### Database sizes

**GET /resources/database-resource-types** — Returns all available database instance sizes with CPU, memory, and storage specs.

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/resources/database-resource-types" })
  return res.body
}
```

Use the `id` field from any of these responses as the corresponding ID parameter when creating or scaling resources.

---

## 6. Users

List all members of the current company and their roles.

**GET /users** — Returns all users in the company with their IDs, names, email addresses, and assigned roles.

```js
async () => {
  const res = await sevalla.request({ method: "GET", path: "/users" })
  return res.body
}
```

---

## 7. Object Storage Management

Advanced object storage operations beyond basic CRUD (bucket creation is covered in `references/setup.md`).

### CORS policies

Configure cross-origin resource sharing for browser-based access to bucket contents.

| Action | Method | Path |
|---|---|---|
| Create | **POST** | `/object-storage/{id}/cors-policies` |
| Update | **PATCH** | `/object-storage/{id}/cors-policies/{policy_id}` |
| Delete | **DELETE** | `/object-storage/{id}/cors-policies/{policy_id}` |

**POST /object-storage/{id}/cors-policies** body:

| Field | Type | Required | Description |
|---|---|---|---|
| allowed_origins | string[] | yes | Origins permitted to make requests (e.g. `["https://example.com"]`) |
| allowed_methods | string[] | yes | HTTP methods to allow (e.g. `["GET", "PUT"]`) |
| allowed_headers | string[] | no | Headers the browser may send |
| max_age | integer | no | Cache duration in seconds for preflight responses |

### CDN domain

Enable a CDN-backed custom domain for public access to bucket objects.

| Action | Method | Path |
|---|---|---|
| Enable CDN domain | **POST** | `/object-storage/{id}/domain` |
| Disable CDN domain | **DELETE** | `/object-storage/{id}/domain` |

### Objects

Browse and manage objects stored in a bucket.

| Action | Method | Path |
|---|---|---|
| List objects | **GET** | `/object-storage/{id}/objects` |
| Bulk delete | **DELETE** | `/object-storage/{id}/objects` |

**Bulk delete** body: `{ "keys": ["file1.png", "dir/file2.pdf"] }`

Pass an array of object keys to delete multiple files in a single request. **Always confirm with the user before bulk deleting objects.**

---

## 8. Device Authorization

OAuth device flow for CLI and external tool authentication. This flow allows headless tools to obtain API tokens without handling user credentials directly.

| Action | Method | Path | Auth required |
|---|---|---|---|
| Create device code | **POST** | `/auth/device-codes` | No |
| Poll status | **GET** | `/auth/device-codes/{code}` | No |

**Flow:**

1. Call **POST /auth/device-codes** to obtain a device code and a user-facing verification URL.
2. Direct the user to open the verification URL in a browser and approve the authorization request in the Sevalla dashboard.
3. Poll **GET /auth/device-codes/{code}** until the status changes from `pending` to `approved`.
4. On approval, the response includes an API token the tool can use for subsequent authenticated requests.

Neither endpoint requires authentication, making this flow suitable for bootstrapping credentials in new environments.
