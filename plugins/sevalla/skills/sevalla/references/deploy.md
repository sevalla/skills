# Deploy — Deployments, Builds, Pipelines, Preview Apps

## 1. Trigger an Application Deployment

**POST /applications/{id}/deployments**

| Body | Behavior |
|---|---|
| `{ "branch": "main" }` | Build & deploy the latest commit from the given branch (Git apps) |
| `{ "docker_image": "registry/image:tag" }` | Deploy a Docker image (Docker apps) |
| `{ "is_restart": true }` | Reuse the last successful build artifact (skip build) — fastest way to pick up new env vars |
| `{}` | Use the configured `default_branch` / `docker_image` |

**Statuses:** `waiting` → `inProgress` → `success` \| `failed` \| `cancelled` \| `skipped`.

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

After triggering, poll status with `GET /applications/{id}/deployments?limit=1`.

## 2. Cancel a Deployment

**POST /applications/{id}/deployments/{deployment_id}/cancel** — cancels a `waiting` or `inProgress` deployment. No body.

**Confirm with the user before cancelling.**

## 3. Roll Back

**POST /applications/{id}/deployments/rollback** — redeploys the previous successful build image; no rebuild.

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/applications/APP_ID/deployments/rollback"
})).body
```

**Confirm with the user before rolling back.** State exactly which deployment will become active again.

## 4. List & Inspect Deployments

| Action | Method | Path |
|---|---|---|
| List | GET | `/applications/{id}/deployments` (paginated) |
| Get | GET | `/applications/{id}/deployments/{deployment_id}` |
| Build logs | GET | `/applications/{id}/deployments/{deployment_id}/logs` |

Deployment objects include `id`, `status`, `branch`, `commit_sha`, `commit_author`, `trigger`, `created_at`, `started_at`, `finished_at`, and a `steps` array (clone → build → push → deploy). For runtime logs, see `references/operate.md`.

## 5. Build Configuration

All build settings are managed via **PATCH /applications/{id}** — they cannot be set on create.

| Field | Description |
|---|---|
| `build_type` | `"nixpacks"` (default), `"dockerfile"`, `"pack"` |
| `build_path` | Repo-relative build directory |
| `dockerfile_path` | Path to Dockerfile (for `dockerfile`) |
| `docker_context` | Docker build context (for `dockerfile`) |
| `pack_builder` | `"heroku/builder:22"` or `"heroku/builder:24"` (for `pack`) |
| `buildpacks` | Array of `{ order, source }` (for `pack`); primary language buildpack has the highest `order` |
| `nixpacks_version` | One of `"1.29"`, `"1.39"`, `"1.41"` |
| `build_cache_enabled` | Boolean |
| `docker_registry_credential_id` | UUID — required for private base images or for `dockerImage` source |

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

## 6. Auto-Deploy Settings

Also via **PATCH /applications/{id}**.

| Field | Type | Description |
|---|---|---|
| `auto_deploy` | boolean | Deploy on push to `default_branch`. **Only works for `privateGit` apps.** |
| `default_branch` | string | Branch that triggers auto-deploy |
| `allow_deploy_paths` | string[] | Glob patterns — only commits touching these trigger deploys |
| `ignore_deploy_paths` | string[] | Glob patterns — commits touching only these are skipped |

`allow_deploy_paths` and `ignore_deploy_paths` are mutually exclusive.

```js
async () => {
  const res = await sevalla.request({
    method: "PATCH",
    path: "/applications/APP_ID",
    body: {
      auto_deploy: true,
      default_branch: "main",
      ignore_deploy_paths: ["docs/**", "README.md"]
    }
  })
  return res.body
}
```

## 7. Deployment Hooks

External URLs that trigger a deploy when called. Useful for CI/CD bridges.

| Action | Method | Path |
|---|---|---|
| Enable | POST | `/applications/{id}/deployment-hook` |
| Get URL | GET | `/applications/{id}/deployment-hook` |
| Regenerate | PUT | `/applications/{id}/deployment-hook` |
| Disable | DELETE | `/applications/{id}/deployment-hook` |

Calling the returned URL from CI triggers a fresh deploy.

## 8. Pipelines

Pipelines move code through stages (dev → staging → prod).

| Type | Behavior |
|---|---|
| `trunk` | Same repo + branch; promote the build image between stages without rebuilding |
| `branch` | Each stage has its own branch |

| Action | Method | Path | Body |
|---|---|---|---|
| Create pipeline | POST | `/pipelines` | `{ display_name, type, project_id? }` |
| Add stage | POST | `/pipelines/{id}/stages` | `{ display_name, insert_before, branch? }` |
| Update stage | PATCH | `/pipelines/{id}/stages/{stage_id}` | `{ display_name?, branch? }` |
| Delete stage | DELETE | `/pipelines/{id}/stages/{stage_id}` | — |
| Add app to stage | POST | `/pipelines/{id}/stages/{stage_id}/apps` | `{ app_id }` |
| Remove app from stage | DELETE | `/pipelines/{id}/stages/{stage_id}/apps/{app_id}` | — |
| Promote | POST | `/pipelines/{id}/promote` | optional `{ from_stage_id, to_stage_id }` |
| Delete pipeline | DELETE | `/pipelines/{id}` | — |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/pipelines",
    body: { display_name: "Web Release Pipeline", type: "trunk" }
  })
  return res.body
}
```

Add a stage at a specific position (0-indexed; existing stages shift up):

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/pipelines/PIPELINE_ID/stages",
    body: { display_name: "Staging", insert_before: 1 }
  })
  return res.body
}
```

Promote (moves the build image to the next stage — no rebuild):

```js
async () => (await sevalla.request({
  method: "POST",
  path: "/pipelines/PIPELINE_ID/promote"
})).body
```

## 9. Preview Apps

Auto-created for pull requests. Inherit env vars and config from the pipeline's first stage. Deleted when the PR closes or merges.

| Action | Method | Path | Body |
|---|---|---|---|
| Enable | POST | `/pipelines/{id}/preview/enable` | `{ repo_url?, auto_create_app?, delete_stale_apps?, stale_app_days? }` |
| Disable | POST | `/pipelines/{id}/preview/disable` | — |
| Update | PUT | `/pipelines/{id}/preview` | same fields as enable |

```js
async () => {
  const res = await sevalla.request({
    method: "POST",
    path: "/pipelines/PIPELINE_ID/preview/enable",
    body: {
      repo_url: "https://github.com/org/repo",
      auto_create_app: true,
      delete_stale_apps: true,
      stale_app_days: 7
    }
  })
  return res.body
}
```

## 10. Static Site Deployments

**POST /static-sites/{id}/deployments** — body is optional.

| Body | Behavior |
|---|---|
| `{}` | Deploy the latest commit on `default_branch` |
| `{ "branch": "feature/x" }` | Deploy a specific branch |
| `{ "deployment_id": "<uuid>" }` | Roll back to that prior deployment (no rebuild) |

Other endpoints follow the application pattern:

| Action | Method | Path |
|---|---|---|
| List | GET | `/static-sites/{id}/deployments` |
| Get | GET | `/static-sites/{id}/deployments/{deployment_id}` |
| Cancel | POST | `/static-sites/{id}/deployments/{deployment_id}/cancel` |
| Build logs | GET | `/static-sites/{id}/deployments/{deployment_id}/logs` |

Static sites do **not** have a separate `/rollback` endpoint — use the `deployment_id` body field above.

## 11. Troubleshooting

| Symptom | Likely cause | Action |
|---|---|---|
| Build fails | Missing dep, wrong runtime version, Dockerfile syntax, wrong `build_path` | Read deployment logs (`/deployments/{deployment_id}/logs`); fix and redeploy |
| Stuck in `waiting` | Another deployment already running | Only one deployment runs at a time per app — cancel it or wait |
| Build succeeds, app crashes | Missing env var, wrong PORT binding, DB unreachable | Check runtime logs (`references/operate.md`); consider rolling back while investigating |
| Auto-deploy not firing | App is not `privateGit`, branch mismatch, path filter excludes commits, Git webhook revoked | Verify `auto_deploy: true`, `default_branch`, deploy-path filters, and that Sevalla has webhook access on the repo |
| `is_restart` ignored | No prior successful build artifact | Trigger a normal deploy first; `is_restart` reuses the last successful image |
| Rollback returns 4xx | No previous successful deployment | Confirm at least one prior successful deploy exists |
