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
- Every secret is a Sevalla variable, not a committed `.env` file.
- The web process has a readiness probe, so rollouts switch over without errors.
- The web process runs at least 2 instances, or autoscales, sized from real metrics.
- Hibernation is off, unless visitors can wait about 90 seconds after a quiet period.
- Nothing the app must keep is written to the local filesystem: it's wiped on every deployment.
- The custom domain is active with SSL, and the web process isn't on `h1`.
- The database is in the app's location, connected internally, with a recent manual backup.
- Migrations run in a `beforeDeployment` job; changes reach production through staging.
- A usage alert warns before spending passes the budget.

## Custom domains

`add_domain` with the domain (`wildcard: true` for all subdomains) returns the DNS records to
create at the user's DNS provider: an ownership `TXT` record (`_cf-custom-hostname`), an SSL
validation record (`_acme-challenge`), and the record that points the domain at Sevalla. Give the
user the records exactly as returned; you can't create them. Then `get_application` shows the
status, and `refreshApplicationDomainStatusV3` checks again. SSL is issued automatically, or
`ssl_certificate` and `ssl_private_key` add the user's own.

- The web process must not be on `h1`, and the company needs a payment method.
- On Cloudflare DNS, the records must be **DNS only** (grey cloud) until the domain is active.
- `setApplicationPrimaryDomainV3` makes a domain the app's address in the dashboard and pipelines.
- Static sites and load balancers have the same operations (`addStaticSiteDomainV3`,
  `addLoadBalancerDomainV3`, and their refresh and set-primary operations).

## Scaling and sizes

`get_platform_options` lists sizes with CPU, memory and the IDs that `scale_process` takes. Every
instance of a process has the same size. Sizes are grouped as Hobby (`h1`), Standard,
CPU optimized and Memory optimized.

- **Fixed instances**: `scale_process` with `instances` (0 to 50; 0 stops the process).
- **Autoscaling**: `scale_process` with `autoscaling` (`min_instances`, `max_instances`,
  `target_cpu_percent` and/or `target_memory_percent`). It scales up when either target is
  exceeded and down when both stay below.
- **Size**: `scale_process` with `size_id`.
- `scale_process` restarts the process from its current build by default (`apply_now`).
- Size it from `get_metrics` (`target: "process"`), not a guess. More or bigger costs more: say so.
- Database sizes only go up (`updateDatabaseV3` with `resource_type_id`). A smaller one means a new
  database and moving the data. Engine, version, location, name and user never change.

## Health checks

Probes go on the web process with `updateProcessV3`: `readiness_probe` (send traffic only when
ready, which gives zero-downtime rollouts) and `liveness_probe` (restart an instance that hangs).

```json
{
  "readiness_probe": {
    "httpGet": { "path": "/healthz", "port": 8080 },
    "initialDelaySeconds": 5,
    "periodSeconds": 10,
    "failureThreshold": 3
  }
}
```

The probe also takes `tcpSocket` (`{ "port": 8080 }`) or `exec` (`{ "command": [...] }`). Probe an
endpoint that doesn't depend on third-party services, so one outage elsewhere doesn't restart
every instance.

## Pause, sleep or show a maintenance page

| Need | Operation | Effect |
| --- | --- | --- |
| Pause until further notice | `suspendApplicationV3`, back with `activateApplicationV3` | Every process stops. Databases: `suspendDatabaseV3`, `activateDatabaseV3` |
| Sleep when idle | `updateApplicationV3` with `hibernation_enabled: true` and `hibernate_after_seconds` | Scales to zero after that many seconds without HTTP requests (the dashboard shows minutes). The next request wakes it, usually within 90 seconds. Cron jobs still run. Not with autoscaling. Applies without a deployment |
| Maintenance page | `updateApplicationMaintenanceModeV3` with `is_enabled` (and `page_url` for your own page) | Every request gets a `503` page at the edge; the app keeps running and can deploy |

Anything held in memory or on the local filesystem is lost when an app sleeps or is suspended.

## Disks

A disk keeps files across deployments and restarts: `updateProcessDiskV3` with
`resource_type_id` (`listDiskResourceTypesV3`) and `mount_path`, for a web process or worker.

- One disk per process. The process is limited to 1 instance and can't autoscale.
- Each deployment stops the old instance before starting the new one: a short interruption.
- A disk can grow, not shrink. `deleteProcessDiskV3` deletes every file on it.

Prefer object storage (S3-compatible, `createObjectStorageV3`) or a database for uploads and
anything several instances share.

## Database backups and restores

Which kind a database has depends on its location's cloud:

- **Google Cloud locations**: a snapshot every day, kept 7 days, plus up to 5 manual ones, kept
  14 days (`createDatabaseBackupV3`, `listDatabaseBackupsV3`).
- **OCI locations**: dumps to an S3-compatible bucket on each backup target's schedule
  (`createDatabaseBackupTargetV3`, `createDatabaseExternalBackupV3`). Manual snapshot backups
  return `400` there.

**Restoring replaces all the data** written since the backup, with a brief outage. Before a
restore: take a manual backup of the current state, name the backup and its time, and get a yes.
Safer when it fits: restore into another database of the same engine and version in the same
location with `restoreDatabaseBackupV3` and `target_database_id`, and check the data there first.
`get_database` shows when the restore is done.

## Network and access

| Need | Operation |
| --- | --- |
| Connect services privately (same location) | `createApplicationInternalConnectionV3`, `createDatabaseInternalConnectionV3` |
| Reach a database from outside (migrations from a laptop, a BI tool) | `toggleDatabaseExternalConnectionV3`; turn it off afterwards |
| Allow or deny IP addresses | `updateApplicationIpRestrictionV3` (`type`, `is_enabled`, `ip_list`), `updateDatabaseIpRestrictionV3` |
| Limit abusive traffic | `updateApplicationRateLimitV3` (`is_enabled`, `action`: `challenge`, `throttle` or `ban`) |
| The IPs the app connects out from, for a partner's allowlist | `getApplicationEgressIpsV3` |
| A non-HTTP port (TCP) from the internet | `createApplicationTcpProxyV3` |
| A port only other services reach | `createApplicationPrivatePortV3` |
| CDN and edge caching (both off by default) | `toggleApplicationCdnV3`, `toggleApplicationEdgeCacheV3`, `purgeApplicationCacheV3` |

An allowlist that is too narrow locks out real users: confirm the list before enabling it.

## Cost

An application is billed by the second for its processes (size times instances), its disks while
their process runs, its build time and its bandwidth; a database by its size. Prices:
https://docs.sevalla.com/billing/pricing.md. Before creating or growing anything, say what it is
and its size. A suspended app isn't billed for its processes and keeps its settings, variables,
disks and domains. `createUsageAlertConfigV3` (`limit_usd`, `emails`, `triggers` as
`[{ "percentage": 80 }]`) emails before spending passes a limit.

## API keys

Every connection is limited by its API key. For an agent that only reads, the **Company viewer**
role. For CI, custom capabilities (`APP:READ`, `APP:UPDATE`) limited to the one application it
deploys. Keys are created under **Tools** > **API keys** in the dashboard, or with
`createApiKeyV3` (`name`, `role_ids` or `capabilities`, `expired_at`), which returns the token
once. `rotateApiKeyV3` takes `old_token_ttl_hours` so CI can switch over before the old token
stops working.
