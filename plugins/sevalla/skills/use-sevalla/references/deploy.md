# Deploy — Sevalla Deployment & Release Management

## 1. Trigger Deployment

**POST** `/applications/{app_id}/deployments`

| Body | Behavior |
|---|---|
| `{ "branch": "main" }` | Deploy latest commit from a specific branch |
| `{ "docker_image": "registry/image:tag" }` | Deploy a Docker image from an external registry |
| `{}` | Restart latest deployment (skips build, reuses last image) |

**Statuses:** `waiting` | `inProgress` | `success` | `failed` | `cancelled` | `skipped`
**Triggers:** `MANUAL_DEPLOY` | `AUTO_DEPLOY` | `ROLLBACK_DEPLOYMENT`

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

After triggering, check status with GET `/applications/{app_id}/deployments?limit=1`.

---

## 2. Cancel Deployment

**POST** `/applications/{app_id}/deployments/{deployment_id}/cancel`

Cancels a deployment in `waiting` or `inProgress` status. No body required.

**Always confirm with the user before cancelling.**

---

## 3. Rollback

**POST** `/applications/{app_id}/deployments/rollback`

Rolls back to the last successful deployment. No body required. Redeploys the previous successful build image without rebuilding.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/applications/APP_ID/deployments/rollback"
  })
  return res.body
}
```

**Always confirm with the user before rolling back.** State clearly that this reverts the running application to its previous successful deployment.

---

## 4. List Deployments

**GET** `/applications/{app_id}/deployments` — paginated (`limit`, `offset`).

Returns deployment history: `id`, `status`, `branch`, `commit_sha`, `commit_author`, `trigger`, `created_at`, `started_at`, `finished_at`.

## 5. Get Deployment Details

**GET** `/applications/{app_id}/deployments/{deployment_id}` — full deployment info including a `steps` array (clone, build, push, deploy) with individual statuses and durations.

## 6. View Deployment Logs

**GET** `/applications/{app_id}/deployments/{deployment_id}/logs` — build logs from each step. Use to diagnose build failures. For runtime logs, see `references/operate.md`.

---

## 7. Build Configuration

Update via **PATCH** `/applications/{app_id}`:

| Field | Description |
|---|---|
| `build_type` | `"nixpacks"` (default), `"dockerfile"`, or `"pack"` |
| `build_path` | Root directory for the build (relative to repo root) |
| `dockerfile_path` | Path to Dockerfile (when `build_type` is `"dockerfile"`) |
| `docker_context` | Docker build context path |
| `pack_builder` | Buildpack builder URL (when `build_type` is `"pack"`) |
| `buildpacks` | Array of buildpack URLs (primary language buildpack must be last) |
| `nixpacks_version` | Pin a specific Nixpacks version |
| `build_cache_enabled` | Boolean — enable/disable build cache |

**Nixpacks** (default): Auto-detects language. Supports 20+ languages. Configurable via `nixpacks.toml` in repo root.

**Dockerfile**: Full control. Required for unsupported languages. Images must be `linux/amd64`.

**Buildpacks**: Heroku-style. Supports Node.js, Ruby, Python, Java, Scala, PHP, Go.

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID",
    body: {
      build_type: "dockerfile",
      dockerfile_path: "Dockerfile",
      docker_context: "."
    }
  })
  return res.body
}
```

---

## 8. Auto-Deploy Settings

Update via **PATCH** `/applications/{app_id}`:

| Field | Type | Description |
|---|---|---|
| `auto_deploy` | boolean | Deploy on every commit to the default branch |
| `default_branch` | string | Branch that triggers auto-deploy |
| `wait_for_checks` | boolean | Wait for CI checks before deploying |
| `allow_deploy_paths` | string[] | Only deploy when these paths change |
| `ignore_deploy_paths` | string[] | Skip deploy when only these paths change |

`allow_deploy_paths` and `ignore_deploy_paths` are mutually exclusive.

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID",
    body: {
      auto_deploy: true,
      default_branch: "main",
      wait_for_checks: true,
      ignore_deploy_paths: ["docs/", "README.md"]
    }
  })
  return res.body
}
```

---

## 9. Deployment Hooks

External trigger URLs for CI/CD integration.

| Action | Method | Path |
|---|---|---|
| Enable | **POST** | `/applications/{app_id}/deployment-hook` |
| Get URL | **GET** | `/applications/{app_id}/deployment-hook` |
| Regenerate | **PUT** | `/applications/{app_id}/deployment-hook` |
| Disable | **DELETE** | `/applications/{app_id}/deployment-hook` |

The response from POST/GET includes the hook URL. Add it as a webhook in your CI/CD system to trigger deployments on successful builds.

---

## 10. Pipelines

Pipelines move code through stages (dev -> staging -> production).

**Types:**
- **trunk** — Same repo, promote between stages without rebuilding
- **branch** — Different branches per stage

| Action | Method | Path |
|---|---|---|
| Create | **POST** | `/pipelines` |
| List | **GET** | `/pipelines` |
| Add stage | **POST** | `/pipelines/{id}/stages` |
| Add app to stage | **POST** | `/pipelines/{id}/stages/{stage_id}/apps` |
| Promote | **POST** | `/pipelines/{id}/promote` |

Create a pipeline:

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/pipelines",
    body: { display_name: "My Pipeline", type: "trunk" }
  })
  return res.body
}
```

Promote to next stage (moves the exact build image without rebuilding):

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/pipelines/PIPELINE_ID/promote"
  })
  return res.body
}
```

When adding a stage, `position` determines order (0-indexed). When adding an app to a stage, provide the `app_id`.

---

## 11. Preview Apps

Automatically created for pull requests. Inherit env vars and config from the pipeline's first stage. Deleted when the PR is closed or merged.

| Action | Method | Path |
|---|---|---|
| Enable | **POST** | `/pipelines/{id}/preview/enable` |
| Disable | **POST** | `/pipelines/{id}/preview/disable` |
| Update settings | **PUT** | `/pipelines/{id}/preview` |

---

## 12. Static Site Deployments

**POST** `/static-sites/{static_site_id}/deployments`

Triggers build and deploy for a static site served via the Cloudflare CDN.

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/static-sites/STATIC_SITE_ID/deployments"
  })
  return res.body
}
```

---

## 13. Troubleshoot Deployments

**Build fails:** Check deployment logs (section 6). Common causes: missing dependencies, wrong Node/Python version, Dockerfile syntax errors, misconfigured `build_path`.

**Deployment stuck in "waiting":** Another deployment may be in progress. Only one deployment runs at a time per application. Cancel it (section 2) or wait.

**Runtime crash after deploy:** Build succeeded but app crashes at startup. Check runtime logs (`references/operate.md`). Common causes: missing env vars, port binding issues (must listen on `PORT`), database connection failures. Consider rolling back (section 3) while investigating.

**Auto-deploy not triggering:** Verify `auto_deploy` is true, commits target the correct `default_branch`, Git provider webhook is active, path rules match changed files, and CI checks pass if `wait_for_checks` is enabled.
