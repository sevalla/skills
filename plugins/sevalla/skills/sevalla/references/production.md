# Run in production on Sevalla

- [Go-live checklist](#go-live-checklist)
- [Custom domains](#custom-domains)
- [Scaling and sizes](#scaling-and-sizes)
- [Health checks](#health-checks)
- [Pause, sleep or show a maintenance page](#pause-sleep-or-show-a-maintenance-page)
- [Disks](#disks)
- [Database backups and restores](#database-backups-and-restores)
- [Network and access](#network-and-access)
- [Cost](#cost)
- [API keys](#api-keys)

## Go-live checklist

Before real users arrive, check and report each item (the full list:
https://docs.sevalla.com/applications/go-live-checklist.md):

- The last deployment is `success`; the runtime version is pinned in the repository.
- The web process listens on `0.0.0.0` and `PORT`.
- Every secret is a Sevalla variable, not a committed `.env` file; build-time values were set
  before the last build.
- The web process has a readiness probe, and a liveness probe if it can hang without crashing.
- The web process runs at least 2 instances, or autoscales, sized from real metrics.
- Hibernation is off, unless visitors can wait about 90 seconds after a quiet period.
- Nothing the app must keep is written to the local filesystem: it's wiped on every deployment.
- The custom domain is active with SSL, the web process isn't on `h1`, and CAA records allow
  Sevalla's certificate authority.
- The database is in the app's location, connected internally, with a recent manual backup.
- Migrations run in a `beforeDeployment` job; changes reach production through staging;
  automatic deployments are on or off on purpose; the user knows how to roll back.
- A usage alert warns before spending passes the budget.

## Custom domains

Before `add_domain`, check the web process's size in `get_application`. Custom domains don't work
with an `h1` web process, and need a company with a payment method or credits. Move the process
to a bigger size first, after the user agrees to the cost. On `h1`, adding a domain fails with
`Custom domains are not available while the web process uses a hobby instance size.`, and once an
app has a custom domain, moving its web process to `h1` fails with
`Cannot create hobby process because app has custom domain`.

`add_domain` with the domain (`wildcard: true` for all subdomains) returns the DNS records to
create at the user's DNS provider: an ownership `TXT` record (`_cf-custom-hostname`), an SSL
validation record (`_acme-challenge`), and the record that points the domain at Sevalla. Give the
user the records exactly as returned; you can't create them. Then `get_application` shows the
status, and `refreshApplicationDomainStatusV3` checks again. SSL is issued automatically, or
`ssl_certificate` and `ssl_private_key` add the user's own.

- On Cloudflare DNS, the records must be **DNS only** (grey cloud) until the domain is active.
- `setApplicationPrimaryDomainV3` makes an active domain the app's address in the dashboard and
  pipelines.
- Static sites use `add_domain` too, then `refreshStaticSiteDomainStatusV3` and
  `setStaticSitePrimaryDomainV3`. Load balancers have `addLoadBalancerDomainV3`.

## Scaling and sizes

`get_platform_options` lists sizes with CPU, memory and the IDs that `scale_process` takes. Every
instance of a process has the same size. Sizes are grouped as Hobby (`h1`), Standard,
CPU optimized and Memory optimized. Offer `h1` only for hobby projects without a custom domain.

- **Fixed instances**: `scale_process` with `instances` (0 to 50; 0 stops the process).
- **Autoscaling**: `scale_process` with `autoscaling` (`min_instances`, `max_instances`,
  `target_cpu_percent`, `target_memory_percent`). A target you leave out defaults to 80%, it isn't
  off. It scales up when either target is exceeded and down when both stay below.
- **Size**: `scale_process` with `size_id`.
- `scale_process` with `apply_now` (the default) redeploys the whole application from its current
  build, so any other pending change to variables or processes goes live with it.
- Size it from `get_metrics` (`target: "process"`), not a guess. More or bigger costs more: say so.
- Database sizes only go up (`updateDatabaseV3` with `resource_type_id`), and a resize makes the
  database briefly unavailable. A smaller size means a new database and moving the data. The
  engine, version, location, database name and user never change; the display name can.

## Health checks

Probes go on the web process with `updateProcessV3` and take effect at the next deployment:
`readiness_probe` sends traffic only to ready instances, which makes rollouts zero-downtime;
`liveness_probe` restarts an instance that hangs. Only `httpGet` probes are supported; the API
refuses `tcpSocket` and `exec` probes with a `400`.

```json
{
  "readiness_probe": {
    "httpGet": { "path": "/healthz" },
    "initialDelaySeconds": 5,
    "periodSeconds": 10,
    "timeoutSeconds": 2,
    "failureThreshold": 3
  }
}
```

`port` defaults to the process's own port; set it only if the health endpoint listens elsewhere.
Set `timeoutSeconds`: left out, it defaults to 120 seconds, far longer than a health check should
wait. Probe an
endpoint that doesn't depend on third-party services, so one outage elsewhere doesn't restart
every instance.

## Pause, sleep or show a maintenance page

| Need | Operation | Effect |
| --- | --- | --- |
| Pause until further notice | `suspendApplicationV3`, back with `activateApplicationV3` | Every process stops and isn't billed. Databases: `suspendDatabaseV3`, `activateDatabaseV3` |
| Sleep when idle | `updateApplicationV3` with `hibernation_enabled: true` and `hibernate_after_seconds` | Scales the web process and workers to zero after that many seconds without HTTP requests (the dashboard shows minutes), so queues stall while it sleeps. The next request wakes it, usually within 90 seconds. Cron jobs still run. Not with autoscaling. Applies without a deployment |
| Maintenance page | `updateApplicationMaintenanceModeV3` with `is_enabled`, and `page_url` for your own page | Every request gets a `503` page at the edge; the app keeps running and can deploy. The update replaces the whole setting: send `page_url` again or it's cleared |

Anything held in memory or on the local filesystem is lost when an app sleeps or is suspended.

## Disks

A disk keeps files across deployments and restarts: `updateProcessDiskV3` with
`resource_type_id` (`listDiskResourceTypesV3`) and `mount_path`, for a web process or worker. It
takes effect at the next deployment.

- One disk per process. Attaching one switches the process to 1 instance, and it can't autoscale.
- Each deployment stops the old instance before starting the new one: a short interruption.
- The mount hides whatever the image has at that path.
- A disk can grow, not shrink. `deleteProcessDiskV3`, or deleting the process, deletes every file.

Prefer object storage (S3-compatible, `createObjectStorageV3`) or a database for uploads and
anything several instances share.

## Database backups and restores

Which kind a database has depends on its location's cloud:

- **Google Cloud locations**: a snapshot every day, kept 7 days, plus up to 5 manual ones, kept
  14 days. `get_database` lists them; `createDatabaseBackupV3` takes one now.
- **OCI locations**: dumps to an S3-compatible bucket on each backup target's schedule
  (`createDatabaseBackupTargetV3`, `createDatabaseExternalBackupV3`). A database without a backup
  target has no backups at all. Manual snapshot backups return `400` there.

`createDatabaseBackupV3` answers `202` when the backup starts, and `400` when it can't: 5 manual
backups already exist (delete one first), the database isn't ready, or another backup is running.
The backup runs in the background: wait until `get_database` lists it before relying on it.

**Restoring replaces all the data** written since the backup. A snapshot restore makes the
database briefly unavailable; a dump restore keeps it down for the whole restore. Before a
restore: take a manual backup of the current state and see it listed, name the backup and its
time to the user, and get a yes. Safer when it fits: restore into a new, empty database of the same
engine and version in the same location with `restoreDatabaseBackupV3` and `target_database_id`,
and check the data there first. Restoring into another database replaces everything in it.

`deleteDatabaseV3` also deletes the database's snapshot backups.

## Network and access

| Need | Operation |
| --- | --- |
| Connect an app to a database or app privately (same location) | `createApplicationInternalConnectionV3` |
| Reach a database from outside (migrations from a laptop, a BI tool) | `toggleDatabaseExternalConnectionV3`; turn it off afterwards |
| Allow or deny IP addresses | `updateApplicationIpRestrictionV3` (`type`, `is_enabled`, `ip_list`), `updateDatabaseIpRestrictionV3` |
| Limit abusive traffic (100 requests a minute per IP) | `updateApplicationRateLimitV3` (`is_enabled`, `action`: `challenge`, `throttle` or `ban`) |
| The IPs the app connects out from, for a partner's allowlist | `getApplicationEgressIpsV3` |
| A non-HTTP port (TCP) from the internet | `createApplicationTcpProxyV3` |
| A port only other services reach | `createApplicationPrivatePortV3` |
| CDN and edge caching (both off by default) | `toggleApplicationCdnV3`, `toggleApplicationEdgeCacheV3`, `purgeApplicationCacheV3` |

Operations named `toggle...` flip the current state: read it first (`get_application` or
`get_database`) so you turn it the way you mean. An allowlist that is too narrow locks out real
users: confirm the list before enabling it.

## Cost

An application is billed for its processes (size times instances), its disks while their process
runs, its build time and its bandwidth; a database for its size. Running resources are billed by
the second, bandwidth by the byte. Prices: https://docs.sevalla.com/billing/pricing.md. Before
creating or growing anything, say what it is and its size. A suspended app isn't billed for its
processes and keeps its settings, variables, disks and domains. `createUsageAlertConfigV3`
(`limit_usd`, `emails`, `triggers` as `[{ "percentage": 80 }]`) emails before spending passes a
limit.

## API keys

Every connection is limited by its API key. For an agent that only reads, the **Company viewer**
role. For CI, custom capabilities limited to the one application it deploys:
`APP:UPDATE` to start a deployment and `APP:READ` to follow it:
`[{ "permission": "APP:READ", "resource_id": "<app-id>" }, { "permission": "APP:UPDATE", "resource_id": "<app-id>" }]`.
The user creates keys under
**Tools** > **API keys** in the dashboard: `createApiKeyV3` would return the token to you.
`rotateApiKeyV3` takes `old_token_ttl_hours`; it defaults to 0, which revokes the old token at
once, so give CI time to switch over.
