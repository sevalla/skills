# Deploy on Sevalla

Each step names the MCP tool, or the operation ID to run with `sevalla_api_*`. CLI equivalents are
in [cli.md](cli.md).

- [Applications](#applications)
- [Processes: workers, cron jobs and migrations](#processes-workers-cron-jobs-and-migrations)
- [Databases](#databases)
- [Environment variables](#environment-variables)
- [Follow a deployment](#follow-a-deployment)
- [Static sites](#static-sites)
- [Docker images](#docker-images)
- [Deploy automatically](#deploy-automatically)
- [Pipelines and preview apps](#pipelines-and-preview-apps)

## Applications

**Git access.** `source: "privateGit"` builds through the company's GitHub, GitLab or Bitbucket
connection. When Sevalla can't see the repository, creating the app fails (often with a `500`):
`listGitProvidersV3` returns each installation with a `settings_url`, where the user grants access.
`source: "publicGit"` takes any public repository URL, without automatic deployments on push.

**Create.** `create_application` with `display_name`, `cluster_id` (`get_platform_options`),
`source`, `repo_url` and `default_branch`, and `deploy: false` so you can finish the setup first.
It creates one web process, listening on port 8080, on size `s1` with 1 instance. A smaller size
(`h1`, the Hobby size) is `scale_process` with its `size_id`; `h1` can't serve custom domains.

**Build settings** go in `updateApplicationV3`:

| Field | Values |
| --- | --- |
| `build_type` | `nixpacks` (the default), `railpack` (its successor, in beta), `pack` (Cloud Native Buildpacks), `dockerfile` |
| `build_path` | The app's folder in a monorepo, for example `apps/web` |
| `dockerfile_path`, `docker_context` | With `dockerfile` |
| `nixpacks_version` | `1.29`, `1.39` or `1.41`, to pin Nixpacks |
| `build_cache_enabled` | `false` turns the build cache off for every deployment |
| `auto_deploy`, `default_branch` | Deploy on every push to that branch (`privateGit` only) |
| `allow_deploy_paths` or `ignore_deploy_paths` | Globs that decide which pushes deploy; one or the other |

Nixpacks and Railpack detect the language and need no configuration for most projects. Choose
`dockerfile` when the repository has a Dockerfile that is meant for production.

## Processes: workers, cron jobs and migrations

An application has one `web` process and any number of others, sharing its build and variables.
`get_application` lists them with their IDs. Add one with `createProcessV3`:

```json
{
  "operation_id": "createProcessV3",
  "path_params": { "id": "<app-id>" },
  "body": {
    "display_name": "Migrate",
    "type": "job",
    "entrypoint": "npm run migrate",
    "job_start_policy": "beforeDeployment",
    "resource_type_id": "<size-id>",
    "scaling_strategy": { "type": "manual", "config": { "instanceCount": 1 } }
  }
}
```

| Type | Use | Fields of its own |
| --- | --- | --- |
| `worker` | Always-on background work: queues, consumers | none |
| `cron` | A command on a schedule | `schedule` (5-field cron), `time_zone` (IANA), `concurrency_policy` |
| `job` | A command at each deployment | `job_start_policy`: `beforeDeployment`, `afterSuccessDeployment` or `afterFailedDeployment` |

Run migrations as a `beforeDeployment` job: a failed migration stops the deployment and the
previous version keeps running. A job has about 5 minutes. Change a process's command, port,
health checks or schedule with `updateProcessV3`; run a cron job now with `triggerProcessCronV3`.

## Databases

`create_database` with `display_name`, `type`, `cluster_id` (the app's location), `size_id`
(`get_platform_options` with `kind: "database"`), and for an app, `connect_to_application_id`.
It creates the database, connects it over the private network and stores the connection URL in
the app's `DATABASE_URL` (or `env_var_name`), unless that variable already exists. The password is
generated on the server and never returned. PostgreSQL takes `extensions`: `vector`, `postgis`,
`cron`. `version` defaults to the newest (`listDatabaseVersionsV3` lists them).

Provisioning takes a few minutes: `get_database` shows when it's ready. The app reads the URL from
its next deployment on.

**An existing database** for another app: `createApplicationInternalConnectionV3` with
`target_type: "database"` connects them, but sets no variable. Build the URL from `get_database`
(`internal_hostname`, `internal_port`, database name, user) and a password the user gives you. If
nobody has it, `resetDatabasePasswordV3` sets a new one, and every app already using the old one
loses access until its variable is updated: ask first.

## Environment variables

`set_environment_variables` creates or updates up to 50 at once and never echoes values.

- **Application** (`scope: "application"`): each variable is available at build and at runtime
  unless you set `buildtime` or `runtime` to `false`.
- **Static site** (`scope: "static_site"`): `production`, `preview` and an optional `branch`.
- **Global** (`scope: "global"`): every application gets it unless it sets the same key.
- A value can reference another variable as `${KEY}`.
- Changes apply at the next deployment. Pass `redeploy: true`, or deploy with `restart: true` when
  only runtime values changed. A value the build inlines needs a full deployment.

`list_environment_variables` shows keys and scoping, never values.

## Follow a deployment

`trigger_deployment` returns a deployment. Poll `get_deployment` every 20 to 30 seconds.

| Status | Meaning |
| --- | --- |
| `waiting` | Queued behind the app's running deployment. One runs at a time, in order |
| `inProgress` | Building or rolling out |
| `success` | Every process runs the new version |
| `failed` | The build, a job or a rollout failed, or it passed 30 minutes. The previous version keeps running unless a process's rollout had already finished |
| `cancelled` | Cancelled while running |
| `skipped` | Cancelled while queued, or a push outside the deploy paths |

Options: `branch`, `commit_sha` (40 characters, applications), `restart: true` (reuse the current
build), `skip_build_cache: true`, `docker_image` (Docker apps). A web process without a readiness
probe counts as ready as soon as its container starts, so visitors can see errors for a few
seconds during each rollout; add one (see [production.md](production.md#health-checks)).

**Verify.** The app's address is `https://<name>.sevalla.app`, in `get_application` under its
domains. It answers `404` until the first rollout completes, even when the domain already shows as
active. Then request `/` and one route that reads from the database.

## Static sites

`create_static_site` with `display_name`, `repo_url`, `default_branch`, and the build:
`build_command`, `published_directory` (`dist`, `build`, `out`, `public`), `node_version`,
`install_command`, `root_directory` for a monorepo. Omitted settings are detected. The first build
starts at once; follow it with `list_deployments` and `get_deployment`. The site's address is
`https://<name>.sevalla.page`, in `get_static_site`.

- A single-page app whose router handles paths in the browser needs a `_redirects` file in the
  publish directory with `/*    /index.html    200`. Many generators copy `public/` into the output.
- `index_file` and `error_file` (for example `404.html`) set the pages served.
- `is_preview_enabled: true` builds a preview for each pull request.
- Roll back with `rollback_deployment` and an earlier `deployment_id`, without rebuilding.
- After a deployment, `purgeStaticSiteCacheV3` clears the CDN cache if old files still show.

## Docker images

`create_application` with `source: "dockerImage"` and `docker_image` (for example
`ghcr.io/acme/storefront:1.4.2`). The image must be built for `linux/amd64`; on Apple silicon,
`docker build --platform linux/amd64`. A private image needs a registry credential:
`createDockerRegistryV3` with `name`, `registry` (`dockerHub`, `github`, `gitlab`, `gcr`, `ecr`,
`digitalOcean`, `custom`), `username` and `secret`, then its ID as
`docker_registry_credential_id`. Deploy a new tag with `trigger_deployment` and `docker_image`.

## Deploy automatically

- **On push**: `auto_deploy: true` on the app (`updateApplicationV3`), or on the static site
  (`updateStaticSiteV3`). Deploy paths keep one push from deploying every app of a monorepo.
- **Deploy hook**: `enableDeploymentHookV3` creates a secret URL that deploys the default branch
  on a `POST`. Don't print it: the user copies it from the app's **Settings** tab into a CI
  secret, because anyone with the URL can deploy.
- **GitHub Actions**: `sevalla/sevalla-deploy@v2.0.0` deploys after tests pass:

  ```yaml
  - uses: sevalla/sevalla-deploy@v2.0.0
    with:
      action: deploy-app
      sevalla-token: ${{ secrets.SEVALLA_TOKEN }}
      app-id: <app-id>
      branch: main
      wait-for-finish: true
  ```

  Other actions: `deploy-static-site`, `promote-app`. Docs:
  https://docs.sevalla.com/developer-tools/github-actions.md.
- **The key for CI** gets custom capabilities limited to the one app it deploys, not a company
  role. The user creates it under **Tools** > **API keys**; `createApiKeyV3` returns the token only
  once.

## Pipelines and preview apps

A pipeline orders apps into stages such as Staging and Production. In a `trunk` pipeline, a change
reaches production by promotion: the same build, no rebuild. In a `branch` pipeline, each stage
deploys its own branch.

| Step | Operation |
| --- | --- |
| Create | `createPipelineV3` with `display_name`, `type` (`trunk` or `branch`) |
| Add a stage | `createPipelineStageV3` with `display_name`, `insert_before` (position) |
| Put an app in a stage | `addAppToPipelineStageV3` with `app_id` |
| Promote | `promotePipelineV3` with `source_app_id` and `target_app_ids` (trunk only) |
| Preview apps for pull requests | `enablePipelinePreviewV3` (`auto_create_app`, `delete_stale_apps`, `stale_app_days`) |
| One preview app now | `createPipelinePreviewAppV3` with `branch` and optional `pull_request_number` |

A staging app is usually `cloneApplicationV3` of production. A clone copies the processes,
environment variables and build settings, and **its first deployment starts at once**: with the
production `DATABASE_URL`, the clone connects to the production database, and a
`beforeDeployment` migration job runs against it. To keep the clone off production data, check the
source's variables and jobs with the user first. Then, right after cloning, cancel the clone's
first deployment with `cancelDeploymentV3` (the build takes minutes, and jobs only run after it),
point its variables at a staging database, and deploy it.
