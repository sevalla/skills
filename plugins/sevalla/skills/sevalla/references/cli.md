# The sevalla CLI

Use the CLI when the MCP tools aren't connected. Install it with `npm install -g @sevalla/cli`
(Node.js 24+) or `brew install sevalla/tap/sevalla`. The user signs in with
`sevalla login` (it opens a browser), or sets `SEVALLA_API_TOKEN` to an API key.

- Add `--json` to every command, and parse the result.
- Don't guess flags. `sevalla schema apps.create` prints the arguments of any command (the path
  with dots); `sevalla schema` alone prints every command.
- Mutating commands take `--dry-run`. Destructive ones ask for confirmation unless `--confirm` is
  passed: pass it only after the user agreed.
- `--data '<json>'` on `apps create` and `apps update` sends API fields that have no flag of
  their own, such as `build_path`.
- An operation without a command (running a command in a process, maintenance mode, rate limits,
  egress IPs) goes through the REST API: find its method and path with the operation ID in the spec,
  https://api.sevalla.com/v3/openapi.json, and send it with `curl` and
  `Authorization: Bearer $SEVALLA_API_TOKEN`.

## Deploy an application with a database

```sh
# Signed in?
sevalla auth status --json

# Locations and sizes
sevalla resources clusters --json
sevalla resources process-types --json
sevalla resources db-types --json

# The application (apps create doesn't deploy)
sevalla apps create --name storefront --cluster <cluster-id> --source privateGit --git-type github --repository https://github.com/acme/storefront --branch main --json

# Only for an app in a subfolder of the repository
sevalla apps update <app-id> --data '{"build_path":"apps/web"}' --json

# The database: the CLI never shows a generated password, so set your own
DB_PASSWORD=$(openssl rand -hex 16)
sevalla databases create --name storefront-db --type postgresql --db-version 17 --cluster <cluster-id> --resource-type <db-size-id> --db-name storefront --db-user storefront --db-password "$DB_PASSWORD" --json

# Repeat until its status is ready; note internal_hostname and internal_port
sevalla databases get <db-id> --json

# Connect them. This adds no variable to the app
sevalla databases connections internal-create <db-id> --target-id <app-id> --target-type app --json

# The connection URL and the other variables, before the first build
sevalla apps env-vars create <app-id> --key DATABASE_URL --value "postgresql://storefront:$DB_PASSWORD@<internal-hostname>:<internal-port>/storefront" --json

# Migrations before each deployment
sevalla apps processes create <app-id> --name migrate --type job --job-start-policy beforeDeployment --command "npm run migrate" --resource-type <size-id> --json

# Deploy, then repeat the get every 20 to 30 seconds until success or failed
sevalla apps deployments trigger <app-id> --json
sevalla apps deployments get <deployment-id> --app-id <app-id> --json
sevalla apps deployments logs <deployment-id> --app-id <app-id> --json

# The sevalla.app address, and the runtime output
sevalla apps get <app-id> --json
sevalla apps logs runtime <app-id> --json
```

Generate the password with letters and digits only (`openssl rand -hex 16`), because it goes into
a URL. Keep it out of the conversation: run the commands so the value stays in the shell.

## Everyday commands

| Task | Command |
| --- | --- |
| List services | `sevalla apps list --json`, `sevalla databases list --json`, `sevalla static-sites list --json` |
| Deployments of an app | `sevalla apps deployments list --app-id <app-id> --json` |
| Roll back, cancel | `sevalla apps deployments rollback <app-id> --json`, `sevalla apps deployments cancel <deployment-id> --app-id <app-id> --json` |
| Processes | `sevalla apps processes list --app-id <app-id> --json` |
| Scale a process | `sevalla apps processes update <process-id> --app-id <app-id> --instances 2 --json` (`--resource-type` for the size) |
| Change a start command | `sevalla apps processes update <process-id> --app-id <app-id> --command "node dist/server.js" --json` |
| Variables | `sevalla apps env-vars list --app-id <app-id> --json`; `sevalla apps env-vars update <env-var-id> --app-id <app-id> --value <value> --json` |
| Access logs | `sevalla apps logs access <app-id> --json` |
| Metrics | `sevalla apps metrics response-time <app-id> --json` |
| Custom domain | `sevalla apps domains add <app-id> --name shop.example.com --json` |
| Copy, suspend, resume | `sevalla apps clone <app-id> --display-name storefront-staging --json`, `sevalla apps suspend <app-id> --json`, `sevalla apps activate <app-id> --json` |
| Manual database backup | `sevalla databases backups create <db-id> --name before-migration --json` |
| New database password | `sevalla databases reset-password <db-id> --new-password <password> --json`, then update the app's variable and deploy |
| Promote in a pipeline | `sevalla pipelines promote <pipeline-id> --source-app-id <app-id> --target-app-ids <app-id> --json` |
| Static site deployment | `sevalla static-sites deployments trigger <site-id> --json`, `sevalla static-sites deployments get <deployment-id> --site-id <site-id> --json` |

Variable changes apply at the next deployment, as with every interface.
