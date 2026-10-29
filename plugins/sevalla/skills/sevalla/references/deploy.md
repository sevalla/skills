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
connection. When Sevalla can't see the repository, creating the app fails with a `400` that says
so: `listGitProvidersV3` returns each connection's `connect_url` (and for GitHub a
`settings_url`), where the user grants access. `source: "publicGit"` takes any public repository
URL, without automatic deployments on push.

**Create.** `create_application` with `display_name`, `cluster_id` (`get_platform_options`),
`source`, `repo_url` and `default_branch`, and `deploy: false` so you can finish the setup first.
It creates one web process, listening on port 8080, on size `s1` with 1 instance. Keep `s1` unless
the user wants the cheaper `h1` (`scale_process` with its `size_id`) for a hobby project without a
custom domain. Check `auto_deploy` in `get_application`, and turn it on if the user wants every
push to deploy.

**Build settings** go in `updateApplicationV3`:

| Field | Values |
| --- | --- |
| `build_type` | `ingot` (the default), `dockerfile`, `railpack`, `pack` (Cloud Native Buildpacks); `nixpacks` is deprecated |
| `build_path` | The app's folder in a monorepo, for example `apps/web` |
| `dockerfile_path`, `docker_context` | With `dockerfile` |
| `build_cache_enabled` | `false` turns the build cache off for every deployment |
| `auto_deploy`, `default_branch` | Deploy on every push to that branch (`privateGit` only) |
| `allow_deploy_paths` or `ignore_deploy_paths` | Globs that decide which pushes deploy; one or the other |

Ingot detects the language, framework, runtime version, package manager and start command,
generates a Dockerfile from them on every build, and needs no configuration for most projects
([frameworks.md](frameworks.md)). It ignores a Dockerfile in the repository: choose `dockerfile`
when that one is meant for production. Don't move an existing app to another builder unless the
user asks: Ingot doesn't read `nixpacks.toml` or `NIXPACKS_*` variables, and its image runs as a
non-root user.

**The Dockerfile a build used.** `listApplicationDockerfilesV3` lists the versions, newest first,
for apps built with `ingot` or `dockerfile`; a deployment's `dockerfile_id` names its version, and
`getApplicationDockerfileV3` returns its Dockerfile. For Ingot, `facts` is what it detected, each
with the file it came from, and `processes` the workers and jobs it suggests. It creates none of
them: weigh each against the project, the way it already runs migrations included.

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

Keep the way the project already runs migrations. When it has migrations and nothing runs them
on deploy, a `beforeDeployment` job is the usual place: it runs once per deployment, before the new
version goes live, and a failed migration stops the deployment while the previous version keeps
running.

- A job has 10 minutes by default; `active_deadline_seconds` on the process changes it.
- A job's own output is in the runtime logs (`search_runtime_logs` around the deployment's time).
  The deployment log only says `<job> has failed` or `<job> has timed out after <N>s`.
- `beforeDeployment` jobs run on every rollout, including restarts, rollbacks and `scale_process`
  changes, so the migration command must be safe to run again (`prisma migrate deploy`,
  `manage.py migrate`, `rails db:migrate` are).

Change a process's command, port, health checks or schedule with `updateProcessV3`; run a cron job
now with `triggerProcessCronV3`, and see its runs of the last 30 days, with each failure's reason
and exit code, with `listProcessCronRunsV3`. New and changed processes take effect at the next
deployment.

## Databases

`create_database` with `display_name`, `type`, `cluster_id` (the app's location), `size_id`
(`get_platform_options` with `kind: "database"`), and for an app, `connect_to_application_id`.
It creates the database, connects it over the private network and stores the connection URL in
the app's `DATABASE_URL` (or `env_var_name`; pass `REDIS_URL` for Redis and Valkey). The password
is generated on the server and never returned. PostgreSQL takes `extensions`: `vector`,
`postgis`, `cron`. `version` defaults to the newest (`listDatabaseVersionsV3` lists them).

Read `connection.env_var` in the result: if the variable already existed, nothing was stored, and
the app still points wherever it pointed before. Provisioning takes a few minutes: wait until
`get_database` shows `ready` before you deploy. The app reads the URL from its next deployment on.

**An existing database** for an app: the agent can't build its URL, because no tool returns the
database's password. Ask the user to connect them on the database's **Networking** tab:
**Add internal connection**, with **Add environment variables to the application** turned on. That
writes the variables without the password passing through you. `resetDatabasePasswordV3` is the
last resort: the database is unavailable for a few minutes, and every app using it breaks until
its variable is updated. Ask first.

## Environment variables

`set_environment_variables` creates or updates up to 50 at once and never echoes values.

- **Application** (`scope: "application"`): each variable is available at build and at runtime
  unless you set `buildtime` or `runtime` to `false`.
- **Static site** (`scope: "static_site"`): `production`, `preview` and an optional `branch`.
- **Global** (`scope: "global"`): every application gets it unless it sets the same key.
- A value can reference another variable as `${KEY}`.
- Changes apply at the next deployment. Pass `redeploy: true`, or deploy with `restart: true` when
  only runtime values changed: a restart reuses the build, so build-time values need a full
  deployment.

`list_environment_variables` shows keys and scoping, never values.

## Follow a deployment

`trigger_deployment` returns a deployment. Check it with `get_deployment` until it reaches
`success`, `failed`, `cancelled` or `skipped`, and report as soon as it does. Between checks, wait
in one shell command (`sleep 60`): each check is a turn, so checking again at once costs more and
finishes no sooner. Without a shell, check every 30 seconds.

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

`create_static_site` with `display_name`, `repo_url`, `default_branch`, and set the build
yourself: `build_command`, `published_directory` (`dist`, `build`, `out`, `public`),
`node_version` (required whenever there is a build or install command: `16`, `18`, `20`, `22`,
`lts` or `latest`; static sites ignore `engines.node`), `install_command`, and `root_directory`
for a monorepo. Without a `build_command`, nothing is built and the repository's files are
published as they are. A new site isn't deployed unless you pass `deploy: true`; otherwise start
its first deployment with `trigger_deployment`, then follow it with `get_deployment`. The site's
address is `https://<name>.sevalla.page`, in `get_static_site`.

- A single-page app whose router handles paths in the browser needs a `_redirects` file in the
  publish directory with `/*    /index.html    200`. Many generators copy `public/` into the output.
- `index_file` and `error_file` (for example `404.html`) set the pages served.
- `is_preview_enabled: true` builds a preview for each pull request; `auto_deploy: true`
  (`updateStaticSiteV3`) deploys every push.
- `rollback_deployment` with an earlier `deployment_id` rebuilds that commit with the current
  settings and variables.
- Old files after a deployment are usually the browser's cache; `purgeStaticSiteCacheV3` clears
  the CDN's.

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
- **Deploy hook**: a secret URL that deploys the default branch on a `POST`. Anyone with the URL
  can deploy, and creating it through the API returns it to you, so let the user turn it on on
  the app's **Settings** tab and copy it straight into a CI secret.
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
  role (see [production.md](production.md#api-keys)). The user creates it under **Tools** >
  **API keys**, so the token goes straight into the CI secret and never through you.

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

A staging app is usually `cloneApplicationV3` of production. A clone copies the processes, the
app's variables and its build settings, including `auto_deploy`. It doesn't copy domains,
internal connections or disk contents, and it doesn't deploy until you deploy it, or until the
next push to its branch if `auto_deploy` is on. Its first deployment then runs with production's
`DATABASE_URL`, and a `beforeDeployment` migration job runs against the production database.
Before either happens: check the source's variables and jobs with the user, set
`auto_deploy: false` on the clone if it shares production's branch, and point its variables at a
staging database. A clone of a Docker image app has no image yet: pass `docker_image` when you
deploy it.
