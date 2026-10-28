# Sevalla API operations

The MCP server's dedicated tools cover everyday work. Everything else runs by operation ID through
one of four tools, by what the operation does:

| Tool | Runs |
| --- | --- |
| `sevalla_api_read` | `GET` operations |
| `sevalla_api_create` | Operations that only add something new |
| `sevalla_api_update` | Operations that change existing state, including suspend, restore, purge and exec |
| `sevalla_api_delete` | Operations that delete |

The call takes `operation_id`, `path_params`, and `query` or `body` when the operation has them.
The service's ID is the path parameter `id`; others are named after what they identify
(`process_id`, `deployment_id`, `domain_id`, `backup_id`, `stage_id`):

```json
{
  "operation_id": "updateProcessV3",
  "path_params": { "id": "<app-id>", "process_id": "<process-id>" },
  "body": { "entrypoint": "node dist/server.js" }
}
```

These IDs are for API v3. When one is refused as unknown, or for anything not listed here,
`sevalla_api_search` with a few keywords returns the current ID, its parameters and its body;
`sevalla_api_search` with `operation_id` returns one operation in full. Look up the body before a
write you haven't made before. With the CLI or the REST API, the same search tells you the method
and path.

- [Applications](#applications)
- [Processes](#processes)
- [Deployments](#deployments)
- [Domains and networking](#domains-and-networking)
- [Databases](#databases)
- [Static sites](#static-sites)
- [Object storage and load balancers](#object-storage-and-load-balancers)
- [Pipelines and projects](#pipelines-and-projects)
- [Account](#account)

## Applications

| Task | Operation ID |
| --- | --- |
| Build settings, auto-deploy, deploy paths, hibernation, source | `updateApplicationV3` |
| Copy an application (deploys at once) | `cloneApplicationV3` (`display_name`, optional `cluster_id`) |
| Stop it until later / start it again | `suspendApplicationV3` / `activateApplicationV3` |
| Maintenance page | `getApplicationMaintenanceModeV3`, `updateApplicationMaintenanceModeV3` (`is_enabled`, `page_url`) |
| Read the deployed repository | `getApplicationRepositoryFileV3`, `listApplicationRepositoryTreeV3`, `searchApplicationRepositoryV3` |
| Purge CDN and edge cache | `purgeApplicationCacheV3` |
| Delete (confirm first) | `deleteApplicationV3` |

## Processes

| Task | Operation ID |
| --- | --- |
| List, read | `listProcessesV3`, `getProcessV3` |
| Add a worker, cron job or job | `createProcessV3` |
| Start command, port, probes, schedule, job policy | `updateProcessV3` |
| Run one command in a running process | `execProcessCommandV3` (`command` as a list, `timeout` up to 60) |
| Run a cron job now | `triggerProcessCronV3` |
| Attach or grow a disk / delete it and its files | `updateProcessDiskV3` (`resource_type_id`, `mount_path`) / `deleteProcessDiskV3` |
| Memory, CPU, instances, exit codes | `get_metrics` with `target: "process"` |
| Delete a process | `deleteProcessV3` |

## Deployments

| Task | Operation ID |
| --- | --- |
| Cancel a running or queued deployment | `cancelDeploymentV3`, `cancelStaticSiteDeploymentV3` |
| Deploy hook | `getDeploymentHookV3`, `enableDeploymentHookV3`, `regenerateDeploymentHookV3`, `disableDeploymentHookV3` |

## Domains and networking

| Task | Operation ID |
| --- | --- |
| List, read, remove | `listApplicationDomainsV3`, `getApplicationDomainV3`, `deleteApplicationDomainV3` |
| Check DNS again now | `refreshApplicationDomainStatusV3` |
| Make primary | `setApplicationPrimaryDomainV3` |
| Turn the sevalla.app domain on or off | `toggleApplicationSystemDomainV3` |
| Internal connection to a database or app | `createApplicationInternalConnectionV3` (`target_id`, `target_type`: `database` or `app`), `listApplicationInternalConnectionsV3` |
| IP allow or deny list | `getApplicationIpRestrictionV3`, `updateApplicationIpRestrictionV3` |
| Rate limiting | `getApplicationRateLimitV3`, `updateApplicationRateLimitV3` |
| Outbound IPs | `getApplicationEgressIpsV3` |
| TCP proxy, private port | `createApplicationTcpProxyV3`, `createApplicationPrivatePortV3` (`process_id`, `port`) |
| CDN, edge cache | `toggleApplicationCdnV3`, `toggleApplicationEdgeCacheV3` |

## Databases

| Task | Operation ID |
| --- | --- |
| Size or name | `updateDatabaseV3` (sizes only go up) |
| Restart | `restartDatabaseV3` |
| Stop it until later / start it again | `suspendDatabaseV3` / `activateDatabaseV3` |
| New password (connected apps lose access until updated) | `resetDatabasePasswordV3` |
| Versions available | `listDatabaseVersionsV3` |
| Connect to an app | `createDatabaseInternalConnectionV3`, `deleteDatabaseInternalConnectionV3` |
| Public access on or off | `toggleDatabaseExternalConnectionV3` |
| IP allow or deny list | `updateDatabaseIpRestrictionV3` |
| Snapshot backups (Google Cloud locations) | `listDatabaseBackupsV3`, `createDatabaseBackupV3` (`display_name`), `restoreDatabaseBackupV3` (optional `target_database_id`) |
| Dump backups (OCI locations) | `listDatabaseBackupTargetsV3`, `createDatabaseBackupTargetV3`, `createDatabaseExternalBackupV3`, `restoreDatabaseExternalBackupV3`, `getDatabaseExternalBackupDownloadUrlV3` |
| Delete (confirm first, show dependents) | `deleteDatabaseV3` |

## Static sites

| Task | Operation ID |
| --- | --- |
| Build settings, branch, previews, deploy paths | `updateStaticSiteV3` |
| Purge the CDN cache | `purgeStaticSiteCacheV3` |
| Pretty URLs (`/about` for `about.html`) | `toggleStaticSitePrettyUrlV3` |
| Domains | `listStaticSiteDomainsV3`, `refreshStaticSiteDomainStatusV3`, `setStaticSitePrimaryDomainV3` |
| Rate limiting | `updateStaticSiteRateLimitV3` |
| Delete (confirm first) | `deleteStaticSiteV3` |

## Object storage and load balancers

| Task | Operation ID |
| --- | --- |
| Buckets | `listObjectStoragesV3`, `createObjectStorageV3`, `getObjectStorageV3` |
| CORS | `createObjectStorageCorsPolicyV3` (`methods`, `origins`, `headers`) |
| Public CDN domain | `createObjectStorageDomainV3`, `deleteObjectStorageDomainV3` |
| Objects | `listObjectStorageObjectsV3`, `deleteObjectStorageObjectsV3` (confirm first) |
| New access keys | `rotateObjectStorageCredentialsV3` (`old_keys_ttl_hours` keeps the old ones working meanwhile) |
| Load balancers | `createLoadBalancerV3`, `createLoadBalancerDestinationV3`, `addLoadBalancerDomainV3` |

## Pipelines and projects

| Task | Operation ID |
| --- | --- |
| Pipelines | `listPipelinesV3`, `getPipelineV3`, `createPipelineV3`, `createPipelineStageV3`, `addAppToPipelineStageV3` |
| Promote a build (trunk pipelines) | `promotePipelineV3` (`source_app_id`, `target_app_ids`) |
| Preview apps | `enablePipelinePreviewV3`, `updatePipelinePreviewSettingsV3`, `createPipelinePreviewAppV3` (`branch`, `pull_request_number`) |
| Projects | `listProjectsV3`, `createProjectV3`, `addServiceToProjectV3` |

## Account

| Task | Operation ID |
| --- | --- |
| Which key is connected, and its permissions | `getCurrentApiKeyV3` |
| API keys | `listApiKeysV3`, `createApiKeyV3`, `rotateApiKeyV3`, `toggleApiKeyV3` |
| Roles and permissions for keys | `listApiKeyRolesV3`, `listApiKeyPermissionsV3` |
| Git connections and repository access | `listGitProvidersV3` |
| Registry credentials | `listDockerRegistriesV3`, `createDockerRegistryV3` |
| Webhooks for platform events | `listWebhooksV3`, `createWebhookV3`, `listWebhookDeliveriesV3` |
| Spending alerts | `listUsageAlertConfigsV3`, `createUsageAlertConfigV3` |
| Company users | `listUsersV3` |
