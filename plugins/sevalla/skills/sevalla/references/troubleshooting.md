# Troubleshooting on Sevalla

Read first, change second. Find the layer that failed, read its log, fix the cause, deploy once.
Quote the log lines that show the cause when you report. After two failed fixes, stop and
re-read, search the docs (`search_sevalla_docs`), or ask.

- [Which layer failed](#which-layer-failed)
- [Build](#build)
- [Rollout and start](#rollout-and-start)
- [The running app](#the-running-app)
- [HTTP errors](#http-errors)
- [Databases](#databases)
- [Custom domains](#custom-domains)
- [Static sites](#static-sites)
- [Look inside a process](#look-inside-a-process)

## Which layer failed

`list_deployments`, then `get_deployment` for the latest one (it carries the build error and the
step that failed):

- `failed` in the build step: [Build](#build).
- Build passed, rollout or a job failed: [Rollout and start](#rollout-and-start). A process whose
  rollout isn't ready in 20 minutes goes back to its previous version.
- `success`, but the site errors or is slow: [The running app](#the-running-app).
- `waiting` for a long time: another deployment of the app is running. One runs at a time.

## Build

`get_deployment_logs`. The last 100 lines usually show the cause; `search` narrows to a text such
as `Error:` or `ERR!`. Don't use `errors_only`: build output on stderr counts as errors, so it
returns hundreds of normal lines.

| The log says | Fix |
| --- | --- |
| The source code cannot be fetched, repository not found | Sevalla can't see the repository: `listGitProvidersV3` returns the `settings_url` where the user grants access. Check `repo_url` and the branch |
| No start command, no language detected | Wrong `build_path` for a monorepo, or no lockfile or manifest at that path |
| The build fails on the language version | Pin it: `engines.node`, `.python-version` |
| Lockfile missing or out of sync | Commit the lockfile after a local install |
| `exit code 126` | A script isn't executable: `chmod +x` in Git, or run it through its interpreter |
| A step needs the database (`ECONNREFUSED`, host not found) | The build can't reach databases: move migrations and data-dependent prerendering to a `beforeDeployment` job or to runtime |
| Killed, out of memory during the build | Lower the build's concurrency, or build with a Dockerfile |
| Image does not exist or incorrect authentication | Docker source: check the image, tag and registry credential |
| The deployment ran out of time | 30 minutes for the whole deployment: cache dependencies, slim the build |

To rebuild without the build cache: `trigger_deployment` with `skip_build_cache: true`.

## Rollout and start

`search_runtime_logs` for the start-up output. Lines on stderr show as `ERROR` too, so search for
the error text rather than filtering by `severity`.

| Cause | Fix |
| --- | --- |
| The server listens on a fixed port or on `localhost` | Listen on `0.0.0.0` and `PORT` |
| A crash at start: a missing variable | `list_environment_variables` (keys only), set it, deploy |
| A job failed (`Migrate has failed`) or ran past about 5 minutes | Read the job's output in the deployment log; check the database variable and connection |
| Failed to deploy, check the entrypoint | The start command doesn't exist in the image: fix it with `updateProcessV3` (`entrypoint`) |
| An ongoing action blocks the deployment | Wait for the other change (a resize, a restart) to finish |

## The running app

`get_metrics` with `target: "process"` and the process ID from `get_application`:
`memory_usage_bytes` against `memory_limit_bytes`, `cpu_usage_cores`, `instance_count`,
`exit_codes`.

| Exit code | Meaning | Fix |
| --- | --- | --- |
| `0` | The process ended | A web process or worker must run a long-lived server or loop |
| `1` | An unhandled error | The stack trace in the runtime logs |
| `127` | Command not found | Fix the start command |
| `137` | Killed, usually out of memory | A bigger size with `scale_process`, or fix the leak |
| `139` | Segmentation fault | A native module built for another architecture: rebuild it in the build |
| `143` | `SIGTERM` | Normal during deployments and scale-downs |

Health checks that fail restart instances: probe a cheap endpoint, with an initial delay longer
than the start-up time. Slow responses: `get_metrics` with `target: "application"`
(`response_time_ms` with `percentile`, `slowest_requests`), then the process's CPU and the
database's metrics.

## HTTP errors

`search_access_logs` with `status` (`404` or `5xx`) shows which paths fail and since when. Who
answered tells you where to look:

| The response | From | Usually |
| --- | --- | --- |
| Your framework's error page | The app | Runtime logs |
| Plain `403 Forbidden` | IP restrictions | `getApplicationIpRestrictionV3` |
| A maintenance page, `503` with `Retry-After: 300` | Maintenance mode | `getApplicationMaintenanceModeV3` |
| `502`, `upstream connect error` | Sevalla's ingress: nothing accepted the connection | Not listening on `0.0.0.0:$PORT`, still starting (add a readiness probe), or a crash |
| `503`, `no healthy upstream` | No ready instance | 0 instances, crashing, starting, waking from hibernation, or suspended |
| `504`, Cloudflare `524` | The request took too long | A slow route: move the work to a worker |
| Cloudflare `520`, `521`, `522` | Cloudflare | `520`: the app crashed mid-request. `521`/`522`: check https://status.sevalla.com |

## Databases

`get_database` shows the status, internal endpoint and internal connections.

| Error | Fix |
| --- | --- |
| Host not found (`ENOTFOUND`, `could not translate host name`) | No internal connection, or the app is in another location: `createApplicationInternalConnectionV3` (same location only) |
| Connection refused, or a variable is missing | The app's variable is missing or stale: set it and deploy |
| Authentication fails | Wrong password in the URL. `resetDatabasePasswordV3` changes it for every app that uses it: ask first |
| The app uses the external hostname | Use the internal hostname and port |
| `Database ... is not in a ready state` | Another change is running, or it's suspended: wait, or `activateDatabaseV3` |
| Storage or memory full | `get_metrics` with `target: "database"`; sizes only go up |

## Custom domains

`get_application` (or `get_static_site`) shows each domain's status, DNS records and verification
errors. `refreshApplicationDomainStatusV3` checks again now; Sevalla also checks every 30 minutes
for 7 days.

| Problem | Fix |
| --- | --- |
| `Custom domains aren't available on the Hobby size.` | The web process is on `h1`: a bigger size with `scale_process` (it costs more: ask) |
| Stays in verification | An old `A` or `CNAME` record still on the name; a doubled record name (`shop.example.com.example.com`); old `_acme-challenge` records; a proxied (orange cloud) Cloudflare record |
| SSL won't issue | A `CAA` record that doesn't allow Sevalla's certificate authority |
| `Domain already exists` | The domain is on another Sevalla service: remove it there first |
| `Add a payment method or credits to add custom domains.` | The company needs a payment method |

## Static sites

| Problem | Fix |
| --- | --- |
| The publish directory is missing | `published_directory` doesn't match the build output (`dist`, `build`, `out`) |
| A single-page app returns 404 on reload | `_redirects` with `/*    /index.html    200` in the publish directory |
| Old content after a deployment | `purgeStaticSiteCacheV3` |
| No deployment after a push | `auto_deploy` off, a public repository, or the push is outside the deploy paths |
| Large files are tiny text files | Git LFS: enable `git_lfs_enabled` on the site |

## Look inside a process

`execProcessCommandV3` (through `sevalla_api_update`) runs one command in a running instance and
returns its output. `command` is an argument list, not a shell line: `["ls", "-la", "/app"]`, not
`ls -la /app | head`. `timeout` is at most 60 seconds. A read-only key can only run read-only
commands. Commands that print the environment (`env`, `printenv`) reveal secrets: don't run them
unless the user asks, and never repeat the values.
