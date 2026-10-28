# The sevalla CLI

Use the CLI when the MCP tools aren't connected. Install it with `npm install -g @sevalla/cli`
(Node.js 24+) or `brew install sevalla/tap/sevalla`.

- [Deploy an application with a database](#deploy-an-application-with-a-database)
- [Everyday commands](#everyday-commands)
- [Operations without a command](#operations-without-a-command)

- **Signed in?** `sevalla api-keys validate --json` makes a real call. (`sevalla auth status` only
  checks that a token is stored, so a revoked key still looks signed in.)
- **Signing in** with `sevalla login` waits for the browser for up to 5 minutes, longer than a tool
  call lasts. Ask the user to run `! sevalla login` themselves, or to set `SEVALLA_API_TOKEN`.
- **No prompts.** The CLI never asks for confirmation. Delete commands fail without `--confirm`;
  pass it only after the user agreed. Some commands that can't be undone have no `--confirm` and
  run at once: `databases backups restore`, `databases reset-password`, `apps suspend`,
  `databases suspend`, `api-keys rotate`, `object-storage rotate-credentials` and
  `apps deployment-hook regenerate`. Get the user's yes before any of them.
- **Flags.** Add `--json` to every command and parse the result. Don't guess flags:
  `sevalla schema apps.create` prints the arguments of any command (the path with dots), and
  `sevalla schema` every command. In the schema, `required` means the option takes a value, not
  that you must pass it.
- **Lists** return 25 items by default: pass `--per-page 100` before you conclude something
  doesn't exist.
- **`--dry-run`** previews most mutating commands, but `processes update`, `env-vars update` and
  `deployments cancel` don't have it, and `databases create --dry-run` prints the password.
- **`--data '<json>'`** replaces the whole request body; it doesn't merge with the other flags. Use
  it with `apps update` for fields without a flag, such as `build_path`.
- **Secrets in output.** `apps env-vars list` prints every value: filter it to keys, as below.
  `env-vars create` echoes the value back: send its output to `/dev/null`.

## Deploy an application with a database

Each command runs in a new shell, so keep the database password in a file only you can read,
outside the repository, and delete it at the end.

```sh
# Signed in?
sevalla api-keys validate --json

# Locations and sizes
sevalla resources clusters --json
sevalla resources process-types --json
sevalla resources db-types --json

# The application (apps create doesn't deploy)
sevalla apps create --name storefront --cluster <cluster-id> --source privateGit --git-type github --repository https://github.com/acme/storefront --branch main --json

# Only for an app in a subfolder of the repository
sevalla apps update <app-id> --data '{"build_path":"apps/web"}' --json

# A password the CLI will never show again, kept out of the conversation
(umask 077 && openssl rand -hex 16 > ~/.sevalla-storefront-db-password)

sevalla databases create --name storefront-db --type postgresql --db-version 17 --cluster <cluster-id> --resource-type <db-size-id> --db-name storefront --db-user storefront --db-password "$(cat ~/.sevalla-storefront-db-password)" --json

# Repeat until its status is ready; note internal_hostname and internal_port
sevalla databases get <db-id> --json

# Connect them. This adds no variable to the app
sevalla databases connections internal-create <db-id> --target-id <app-id> --target-type app --json

# The connection URL, before the first build; the output would echo it, so discard it
sevalla apps env-vars create <app-id> --key DATABASE_URL --value "postgresql://storefront:$(cat ~/.sevalla-storefront-db-password)@<internal-hostname>:<internal-port>/storefront" --json > /dev/null

# Migrations before each deployment
sevalla apps processes create <app-id> --name migrate --type job --job-start-policy beforeDeployment --command "npm run migrate" --resource-type <size-id> --json

# Deploy, then repeat the get every 20 to 30 seconds until success, failed, cancelled or skipped
sevalla apps deployments trigger <app-id> --json
sevalla apps deployments get <deployment-id> --app-id <app-id> --json
sevalla apps deployments logs <deployment-id> --app-id <app-id> --json

# The sevalla.app address is the SYSTEM domain
sevalla apps domains list --app-id <app-id> --json

# The runtime output
sevalla apps logs runtime <app-id> --json

rm ~/.sevalla-storefront-db-password
```

## Everyday commands

| Task | Command |
| --- | --- |
| List services | `sevalla apps list --per-page 100 --json`, `sevalla databases list --per-page 100 --json`, `sevalla static-sites list --per-page 100 --json` |
| Deployments of an app | `sevalla apps deployments list --app-id <app-id> --json` |
| Roll back, cancel | `sevalla apps deployments rollback <app-id> --json`, `sevalla apps deployments cancel <deployment-id> --app-id <app-id> --json` |
| Processes | `sevalla apps processes list --app-id <app-id> --json` |
| Scale a process | `sevalla apps processes update <process-id> --app-id <app-id> --instances 2 --json` (`--resource-type` for the size) |
| Change a start command | `sevalla apps processes update <process-id> --app-id <app-id> --command "node dist/server.js" --json` |
| Variable keys | `sevalla apps env-vars list --app-id <app-id> --json \| jq '[.[] \| {id, key}]'` |
| Change a variable | `sevalla apps env-vars update <env-var-id> --app-id <app-id> --value <value> --json > /dev/null` |
| Access logs | `sevalla apps logs access <app-id> --json` |
| Metrics | `sevalla apps metrics response-time <app-id> --json` |
| Custom domain (check the web process isn't on `h1` first) | `sevalla apps domains add <app-id> --name shop.example.com --json` |
| Copy, suspend, resume | `sevalla apps clone <app-id> --display-name storefront-staging --json`, `sevalla apps suspend <app-id> --json`, `sevalla apps activate <app-id> --json` |
| Manual database backup | `sevalla databases backups create <db-id> --name before-migration --json` |
| Promote in a pipeline | `sevalla pipelines promote <pipeline-id> --source-app-id <app-id> --target-app-ids <app-id> --json` |
| Static site deployment | `sevalla static-sites deployments trigger <site-id> --json`, `sevalla static-sites deployments get <deployment-id> --site-id <site-id> --json` |

Variable changes apply at the next deployment, as with every interface.

## Operations without a command

Running a command in a process, maintenance mode, rate limits and egress IPs go through the REST
API. Find the operation's method and path by its ID in https://api.sevalla.com/v3/openapi.json.
`sevalla login` doesn't set `SEVALLA_API_TOKEN`; it stores the key in
`~/.config/sevalla/credentials.json`. Read it inside the same command, so it's never printed:

```sh
curl -sS -X PUT https://api.sevalla.com/v3/applications/<app-id>/maintenance-mode -H "Authorization: Bearer ${SEVALLA_API_TOKEN:-$(jq -r .token ~/.config/sevalla/credentials.json)}" -H "Content-Type: application/json" -d '{"is_enabled": true}'
```
