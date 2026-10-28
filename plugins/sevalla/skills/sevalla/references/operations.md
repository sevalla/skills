# Sevalla API operations

The MCP server's dedicated tools cover everyday work. Everything else runs by operation ID through
one of four generic tools. The server picks the tool by the operation, not by its name:

- `GET` operations run on `sevalla_api_read`, `DELETE` operations on `sevalla_api_delete`.
- A short list of operations that only add something new run on `sevalla_api_create`. Every other
  `POST`, `PUT` or `PATCH` runs on `sevalla_api_update`, even when its ID starts with `create`.
- An operation that has a dedicated tool is refused by all four: use that tool.

The **Tool** column below says which one runs each operation. For an operation not listed here,
`sevalla_api_search` with a few keywords returns its ID, parameters, body and `tool`: that `tool`
is always right. `sevalla_api_search` with `operation_id` returns one operation in full. Look up
the body before a write you haven't made before.

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

With the CLI or the REST API, find the operation's method and path by its ID in the spec,
https://api.sevalla.com/v3/openapi.json.

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

| Task | Operation ID | Tool |
| --- | --- | --- |
| Build settings, auto-deploy, deploy paths, hibernation, source | `updateApplicationV3` | `sevalla_api_update` |
| Copy an application (copies variables and auto-deploy; see [deploy.md](deploy.md#pipelines-and-preview-apps)) | `cloneApplicationV3` (`display_name`, optional `cluster_id`) | `sevalla_api_create` |
| Stop it until later / start it again | `suspendApplicationV3` / `activateApplicationV3` | `sevalla_api_update` |
| Maintenance page (the update replaces the whole setting) | `updateApplicationMaintenanceModeV3` (`is_enabled`, `page_url`) | `sevalla_api_update` |
| Maintenance page state | `getApplicationMaintenanceModeV3` | `sevalla_api_read` |
| Read the deployed repository | `getApplicationRepositoryFileV3`, `listApplicationRepositoryTreeV3`, `searchApplicationRepositoryV3` | `sevalla_api_read` |
| Purge CDN and edge cache | `purgeApplicationCacheV3` | `sevalla_api_update` |
| Delete (confirm first) | `deleteApplicationV3` | `sevalla_api_delete` |

## Processes

`get_application` lists the processes and their IDs.

| Task | Operation ID | Tool |
| --- | --- | --- |
| Add a worker, cron job or job | `createProcessV3` | `sevalla_api_create` |
| Start command, port, probes, schedule, job policy | `updateProcessV3` | `sevalla_api_update` |
| Run one command in a running process | `execProcessCommandV3` (`command` as a list, `timeout` up to 60) | `sevalla_api_update` |
| Run a cron job now | `triggerProcessCronV3` | `sevalla_api_update` |
| Attach or grow a disk | `updateProcessDiskV3` (`resource_type_id`, `mount_path`) | `sevalla_api_update` |
| Delete a disk and its files / a process | `deleteProcessDiskV3` / `deleteProcessV3` | `sevalla_api_delete` |

## Deployments

| Task | Operation ID | Tool |
| --- | --- | --- |
| Cancel a running or queued deployment | `cancelDeploymentV3`, `cancelStaticSiteDeploymentV3` | `sevalla_api_update` |
| Is a deploy hook on | `getDeploymentHookV3` | `sevalla_api_read` |
| Turn off the deploy hook | `disableDeploymentHookV3` | `sevalla_api_delete` |

Creating or regenerating a deploy hook (`enableDeploymentHookV3`, `regenerateDeploymentHookV3`)
returns its secret URL to you: let the user do it on the app's **Settings** tab instead.

## Domains and networking

| Task | Operation ID | Tool |
| --- | --- | --- |
| List, read | `listApplicationDomainsV3`, `getApplicationDomainV3` | `sevalla_api_read` |
| Remove a domain | `deleteApplicationDomainV3` | `sevalla_api_delete` |
| Check DNS again now | `refreshApplicationDomainStatusV3` | `sevalla_api_update` |
| Make an active domain primary | `setApplicationPrimaryDomainV3` | `sevalla_api_update` |
| Turn the sevalla.app domain on or off (flips the current state) | `toggleApplicationSystemDomainV3` | `sevalla_api_update` |
| Connect an app to an existing database or app | `createApplicationInternalConnectionV3` (`target_id`, `target_type`: `database` or `app`) | `sevalla_api_create` |
| An app's internal connections | `listApplicationInternalConnectionsV3` | `sevalla_api_read` |
| IP allow or deny list | `updateApplicationIpRestrictionV3` | `sevalla_api_update` |
| Its current setting | `getApplicationIpRestrictionV3` | `sevalla_api_read` |
| Outbound IPs | `getApplicationEgressIpsV3` | `sevalla_api_read` |
| Private port | `createApplicationPrivatePortV3` (`process_id`, `port`) | `sevalla_api_create` |
| TCP proxy | `createApplicationTcpProxyV3` (`process_id`, `port`) | `sevalla_api_update` |
| CDN, edge cache (each flips the current state) | `toggleApplicationCdnV3`, `toggleApplicationEdgeCacheV3` | `sevalla_api_update` |

## Databases

Connect an existing database to an app with `createApplicationInternalConnectionV3` above, or from
the database's side with `createDatabaseInternalConnectionV3` (`target_type: "app"`), both on
`sevalla_api_create`. For a new database, `create_database` with `connect_to_application_id` does
both at once.

| Task | Operation ID | Tool |
| --- | --- | --- |
| Size or name | `updateDatabaseV3` (sizes only go up) | `sevalla_api_update` |
| Restart | `restartDatabaseV3` | `sevalla_api_update` |
| Stop it until later / start it again | `suspendDatabaseV3` / `activateDatabaseV3` | `sevalla_api_update` |
| New password (connected apps keep the old one until updated) | `resetDatabasePasswordV3` | `sevalla_api_update` |
| Versions available | `listDatabaseVersionsV3` | `sevalla_api_read` |
| Remove a connection | `deleteDatabaseInternalConnectionV3` | `sevalla_api_delete` |
| Public access on or off (flips the current state) | `toggleDatabaseExternalConnectionV3` | `sevalla_api_update` |
| IP allow or deny list | `updateDatabaseIpRestrictionV3` | `sevalla_api_update` |
| Snapshot backup now (Google Cloud locations; `get_database` lists backups) | `createDatabaseBackupV3` (`display_name`) | `sevalla_api_create` |
| Restore a snapshot backup | `restoreDatabaseBackupV3` (optional `target_database_id`) | `sevalla_api_update` |
| Dump backups (OCI locations) | `createDatabaseBackupTargetV3`, `createDatabaseExternalBackupV3`, `restoreDatabaseExternalBackupV3` | `sevalla_api_update` |
| Dump backup targets and files | `listDatabaseBackupTargetsV3`, `getDatabaseExternalBackupDownloadUrlV3` | `sevalla_api_read` |
| Delete (confirm first, show dependents; deletes its snapshot backups too) | `deleteDatabaseV3` | `sevalla_api_delete` |

## Static sites

| Task | Operation ID | Tool |
| --- | --- | --- |
| Build settings, branch, previews, deploy paths | `updateStaticSiteV3` | `sevalla_api_update` |
| Purge the CDN cache | `purgeStaticSiteCacheV3` | `sevalla_api_update` |
| Pretty URLs (`/about` for `about.html`; flips the current state) | `toggleStaticSitePrettyUrlV3` | `sevalla_api_update` |
| Domains | `listStaticSiteDomainsV3` | `sevalla_api_read` |
| Check DNS again, make primary | `refreshStaticSiteDomainStatusV3`, `setStaticSitePrimaryDomainV3` | `sevalla_api_update` |
| Delete (confirm first) | `deleteStaticSiteV3` | `sevalla_api_delete` |

## Object storage and load balancers

| Task | Operation ID | Tool |
| --- | --- | --- |
| List, read buckets and objects | `listObjectStoragesV3`, `getObjectStorageV3`, `listObjectStorageObjectsV3` | `sevalla_api_read` |
| New bucket, new load balancer | `createObjectStorageV3`, `createLoadBalancerV3` | `sevalla_api_create` |
| CORS, public CDN domain | `createObjectStorageCorsPolicyV3` (`methods`, `origins`, `headers`), `createObjectStorageDomainV3` | `sevalla_api_update` |
| Delete objects (confirm first), remove the CDN domain | `deleteObjectStorageObjectsV3`, `deleteObjectStorageDomainV3` | `sevalla_api_delete` |
| New access keys (`old_keys_ttl_hours` defaults to 0, which revokes the old ones at once) | `rotateObjectStorageCredentialsV3` | `sevalla_api_update` |
| Load balancer destinations and domains | `createLoadBalancerDestinationV3`, `addLoadBalancerDomainV3` | `sevalla_api_update` |

## Pipelines and projects

| Task | Operation ID | Tool |
| --- | --- | --- |
| List, read | `listPipelinesV3`, `getPipelineV3`, `listProjectsV3` | `sevalla_api_read` |
| New pipeline, stage or project | `createPipelineV3`, `createPipelineStageV3`, `createProjectV3` | `sevalla_api_create` |
| Put an app in a stage, a service in a project | `addAppToPipelineStageV3`, `addServiceToProjectV3` | `sevalla_api_update` |
| Promote a build (trunk pipelines) | `promotePipelineV3` (`source_app_id`, `target_app_ids`) | `sevalla_api_update` |
| Preview apps on, and their settings | `enablePipelinePreviewV3`, `updatePipelinePreviewSettingsV3` | `sevalla_api_update` |
| One preview app now | `createPipelinePreviewAppV3` (`branch`, `pull_request_number`) | `sevalla_api_create` |

## Account

| Task | Operation ID | Tool |
| --- | --- | --- |
| Which key is connected, and its permissions | `getCurrentApiKeyV3` | `sevalla_api_read` |
| Keys, roles and permissions | `listApiKeysV3`, `listApiKeyRolesV3`, `listApiKeyPermissionsV3` | `sevalla_api_read` |
| Rotate or turn off a key (`toggleApiKeyV3` flips the current state) | `rotateApiKeyV3`, `toggleApiKeyV3` | `sevalla_api_update` |
| Git connections and repository access | `listGitProvidersV3` | `sevalla_api_read` |
| Registry credential for private images | `createDockerRegistryV3` | `sevalla_api_create` |
| Webhooks, spending alerts | `createWebhookV3`, `createUsageAlertConfigV3` | `sevalla_api_update` |
| Webhook deliveries, alerts, users | `listWebhookDeliveriesV3`, `listUsageAlertConfigsV3`, `listUsersV3` | `sevalla_api_read` |

Creating an API key (`createApiKeyV3`) returns its token to you: let the user create keys under
**Tools** > **API keys** in the dashboard instead.
