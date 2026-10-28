# The sevalla CLI

Use the CLI when the MCP tools aren't connected. Install it with `npm install -g @sevalla/cli`
(Node.js 24+) or `brew install sevalla/tap/sevalla`. This page is for version 2.0 or later;
older versions run irreversible commands without asking for `--confirm`.

- [Deploy an application with a database](#deploy-an-application-with-a-database)
- [Everyday commands](#everyday-commands)
- [Operations without a command](#operations-without-a-command)

- **Signed in?** `sevalla auth status --json` checks the stored token with the API and reports a
  rejected one.
- **Signing in** with `sevalla login` waits for the browser for up to 5 minutes, longer than a tool
  call lasts. Ask the user to sign in themselves (in Claude Code, by typing `! sevalla login`), or
  to set `SEVALLA_API_TOKEN`.
- **`--confirm`.** The CLI never prompts. Deletes and other commands that can't be undone (restore,
  reset a password, suspend, rotate keys or credentials, regenerate or disable a deploy hook) fail
  without `--confirm`. Pass it only after the user agreed to that exact action.
- **Flags.** Add `--json` to every command and parse the result. Don't guess flags:
  `sevalla schema apps.create` prints the arguments of any command (the path with dots), and
  `sevalla schema` every command. In the schema, `mandatory` says whether you must pass an option.
- **Lists** return 25 items a page and say on stderr when there are more: pass `--per-page 100`
  before you conclude something doesn't exist.
- **`--dry-run`** previews mutating commands, with passwords and secrets masked.
- **`--data '<json>'`** sends API fields that have no flag, such as `build_path` on `apps update`.
  It can't be combined with the flags it replaces.
- **Secrets in output.** `env-vars list` shows keys only unless you pass `--show-values`: don't.
  `env-vars create` and `update` don't echo the value.

## Deploy an application with a database

Each command runs in a new shell, so keep the database password in a file only you can read,
outside the repository, and delete it at the end.

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

# A password the CLI will never show again, kept out of the conversation
(umask 077 && openssl rand -hex 16 > ~/.sevalla-storefront-db-password)

sevalla databases create --name storefront-db --type postgresql --db-version 17 --cluster <cluster-id> --resource-type <db-size-id> --db-name storefront --db-user storefront --db-password "$(cat ~/.sevalla-storefront-db-password)" --json

# Repeat until its status is ready; note internal_hostname and internal_port
sevalla databases get <db-id> --json

# Connect them. This adds no variable to the app
sevalla databases connections internal-create <db-id> --target-id <app-id> --target-type app --json

# The connection URL, before the first build
sevalla apps env-vars create <app-id> --key DATABASE_URL --value "postgresql://storefront:$(cat ~/.sevalla-storefront-db-password)@<internal-hostname>:<internal-port>/storefront" --json

# Migrations before each deployment
sevalla apps processes create <app-id> --name migrate --type job --job-start-policy beforeDeployment --command "npm run migrate" --resource-type <size-id> --json

# Deploy, then repeat the get every 20 to 30 seconds until success, failed, cancelled or skipped
sevalla apps deployments trigger <app-id> --json
sevalla apps deployments get <deployment-id> --app-id <app-id> --json
sevalla apps deployments logs <deployment-id> --app-id <app-id> --json

# The sevalla.app address is primary_domain
sevalla apps get <app-id> --json

# The runtime output
sevalla apps logs runtime <app-id> --json

rm ~/.sevalla-storefront-db-password
```

## Everyday commands

| Task | Command |
| --- | --- |
| List services | `sevalla apps list --per-page 100 --json`, `sevalla databases list --per-page 100 --json`, `sevalla static-sites list --per-page 100 --json` |
| Deployments of an app | `sevalla apps deployments list --app-id <app-id> --json` |
| Deploy one commit, rebuild without cache, restart | `sevalla apps deployments trigger <app-id> --commit <sha> --json`, `--skip-build-cache`, `--restart` |
| Roll back, cancel | `sevalla apps deployments rollback <app-id> --json`, `sevalla apps deployments cancel <deployment-id> --app-id <app-id> --json` |
| Processes | `sevalla apps processes list --app-id <app-id> --json` |
| Scale a process | `sevalla apps processes update <process-id> --app-id <app-id> --instances 2 --json` (`--resource-type` for the size) |
| Change a start command | `sevalla apps processes update <process-id> --app-id <app-id> --command "node dist/server.js" --json` |
| Variable keys | `sevalla apps env-vars list --app-id <app-id> --json` |
| Change a variable | `sevalla apps env-vars update <env-var-id> --app-id <app-id> --value <value> --json` |
| Access logs | `sevalla apps logs access <app-id> --json` |
| Metrics | `sevalla apps metrics response-time <app-id> --json` |
| Custom domain (check the web process isn't on `h1` first) | `sevalla apps domains add <app-id> --name shop.example.com --json` |
| Copy | `sevalla apps clone <app-id> --display-name storefront-staging --json` |
| Suspend (after the user agreed), resume | `sevalla apps suspend <app-id> --confirm --json`, `sevalla apps activate <app-id> --json` |
| Manual database backup | `sevalla databases backups create <db-id> --name before-migration --json` |
| Promote in a pipeline | `sevalla pipelines promote <pipeline-id> --source-app-id <app-id> --target-app-ids <app-id> --json` |
| Static site deployment | `sevalla static-sites deployments trigger <site-id> --json`, `sevalla static-sites deployments get <deployment-id> --site-id <site-id> --json` |

Variable changes apply at the next deployment, as with every interface.

## Operations without a command

Running a command in a process, maintenance mode and egress IPs go through the REST
API. Find the operation's method and path by its ID in https://api.sevalla.com/v3/openapi.json.
`sevalla login` doesn't set `SEVALLA_API_TOKEN`; it stores the key in
`~/.config/sevalla/credentials.json`. Read it inside the same command, so it's never printed:

```sh
curl -sS -X PUT https://api.sevalla.com/v3/applications/<app-id>/maintenance-mode -H "Authorization: Bearer ${SEVALLA_API_TOKEN:-$(jq -r .token ~/.config/sevalla/credentials.json)}" -H "Content-Type: application/json" -d '{"is_enabled": true}'
```
