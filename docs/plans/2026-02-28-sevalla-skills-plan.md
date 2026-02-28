# Sevalla Skills Repository Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete AI agent skills repository for managing Sevalla PaaS infrastructure via MCP tools and REST API.

**Architecture:** Single `use-sevalla` skill with routing SKILL.md dispatching to 5 lazy-loaded reference files (setup, deploy, configure, operate, manage). MCP-first interaction through search/execute tools. Claude Code plugin structure with hooks and multi-tool installer.

**Tech Stack:** Markdown (skill files), Bash (scripts, hooks), JSON (plugin metadata)

---

### Task 1: Repository scaffolding and plugin metadata

**Files:**
- Create: `.claude-plugin/marketplace.json`
- Create: `plugins/sevalla/.claude-plugin/plugin.json`
- Create: `LICENSE`
- Create: `.gitignore`

**Step 1: Create directory structure**

```bash
mkdir -p .claude-plugin
mkdir -p plugins/sevalla/.claude-plugin
mkdir -p plugins/sevalla/hooks
mkdir -p plugins/sevalla/skills/use-sevalla/references
mkdir -p plugins/sevalla/skills/use-sevalla/scripts
mkdir -p scripts
```

**Step 2: Create marketplace.json**

Create `.claude-plugin/marketplace.json` — the Claude Code marketplace listing that makes this repo installable as a plugin.

**Step 3: Create plugin.json**

Create `plugins/sevalla/.claude-plugin/plugin.json` — plugin identity metadata (name, version, author, license, repo URL).

**Step 4: Create LICENSE**

MIT license, copyright Sevalla.

**Step 5: Create .gitignore**

Standard ignores: `.DS_Store`, `node_modules/`, `.env`, etc.

**Step 6: Verify structure and commit**

```bash
find . -type f | sort
git add -A && git commit -m "chore: scaffold repo structure and plugin metadata"
```

---

### Task 2: Hook system for auto-approval

**Files:**
- Create: `plugins/sevalla/hooks/hooks.json`
- Create: `plugins/sevalla/hooks/auto-approve-mcp.sh`

**Step 1: Create hooks.json**

Define a `PreToolUse` hook on the `Bash` tool matcher that runs `auto-approve-mcp.sh` to auto-approve Sevalla API calls. This prevents agents from being blocked on every API interaction.

**Step 2: Create auto-approve-mcp.sh**

Bash script that checks if the command contains `sevalla-api.sh` or `curl.*api.sevalla.com` and exits 0 (approve) if so, exits 1 (ask user) otherwise.

**Step 3: Verify and commit**

```bash
chmod +x plugins/sevalla/hooks/auto-approve-mcp.sh
bash -n plugins/sevalla/hooks/auto-approve-mcp.sh  # syntax check
git add plugins/sevalla/hooks/ && git commit -m "feat: add hook system for auto-approving Sevalla API calls"
```

---

### Task 3: sevalla-api.sh fallback script

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/scripts/sevalla-api.sh`

**Step 1: Create sevalla-api.sh**

Bash script that:
1. Reads `SEVALLA_API_KEY` from environment (or prompts)
2. Accepts method, path, and optional JSON body as arguments
3. Sends request to `https://api.sevalla.com/v3{path}` with Bearer auth
4. Pipes response through `jq` if available
5. Handles errors gracefully

Usage: `./sevalla-api.sh GET /applications`
Usage: `./sevalla-api.sh POST /applications '{"display_name":"my-app",...}'`

**Step 2: Verify and commit**

```bash
chmod +x plugins/sevalla/skills/use-sevalla/scripts/sevalla-api.sh
bash -n plugins/sevalla/skills/use-sevalla/scripts/sevalla-api.sh
git add plugins/sevalla/skills/use-sevalla/scripts/ && git commit -m "feat: add sevalla-api.sh REST API helper script"
```

---

### Task 4: SKILL.md — the main routing skill

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/SKILL.md`

**Step 1: Write SKILL.md**

This is the core file. It must contain:

1. **YAML frontmatter:**
   - `name: use-sevalla`
   - `description:` comprehensive trigger description mentioning Sevalla, deploy, hosting, database, static site, object storage, domains, environment variables, logs, metrics, scaling, pipelines, backups, load balancers
   - `allowed-tools:` Bash(sevalla-api.sh:*), Bash(curl:*), Bash(which:*), Bash(jq:*)

2. **Resource model** (~20 lines):
   Explain the hierarchy: Company → Project → Services (Applications, Databases, Static Sites, Object Storage, Load Balancers). Each service type and what it does.

3. **MCP preflight** (~15 lines):
   Check if MCP tools `search` and `execute` are available. If yes, use MCP. If no, fall back to `sevalla-api.sh`. Always require `SEVALLA_API_KEY` for the fallback path.

4. **Quick operations** (~40 lines):
   8 most common operations with inline MCP execute snippets:
   - List applications
   - Get application details
   - List databases
   - Trigger deployment
   - View runtime logs
   - Check deployment status
   - List environment variables
   - Get available regions

5. **Routing table** (~20 lines):

   | Intent | Reference | Use for |
   |---|---|---|
   | Create or provision resources | references/setup.md | Projects, apps, databases, static sites, object storage |
   | Deploy code or manage releases | references/deploy.md | Deployments, builds, rollbacks, pipelines, preview apps |
   | Change configuration | references/configure.md | Env vars, domains, scaling, networking, IP restrictions |
   | Check health or debug issues | references/operate.md | Logs, metrics, backups, health checks, troubleshooting |
   | Manage platform resources | references/manage.md | API keys, webhooks, load balancers, registries |

   Rule: Load only 1-2 references per request.

6. **Execution rules** (~20 lines):
   - MCP-first: use `search` to discover, `execute` to act
   - Always search before executing unfamiliar endpoints
   - Confirm destructive actions (delete, suspend) with user
   - Verify after mutation (re-read resource to confirm changes)
   - Use pagination for list operations (default limit 25, max 100)

7. **Composition patterns** (~25 lines):
   Multi-step workflow examples:
   - First deploy: create project → create app → set env vars → trigger deploy → add domain
   - Fix failure: check deployment status → get logs → identify error → fix → redeploy
   - Add database: create database → create internal connection → set env vars on app → redeploy
   - Scale up: check metrics → update pod size or instance count → verify

8. **Response format** (~10 lines):
   What was done, the result, what to do next.

**Step 2: Verify frontmatter and commit**

```bash
head -10 plugins/sevalla/skills/use-sevalla/SKILL.md  # check frontmatter
git add plugins/sevalla/skills/use-sevalla/SKILL.md && git commit -m "feat: add main SKILL.md routing skill"
```

---

### Task 5: references/setup.md

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/references/setup.md`

**Step 1: Write setup.md**

Cover all provisioning operations with MCP code snippets:

1. **List & discover resources**: List projects, apps, databases, static sites, object storage
2. **Create project**: POST /projects with display_name
3. **Create application**:
   - From private Git (GitHub/GitLab/Bitbucket): source, repo, branch, build_type
   - From public Git URL
   - From Docker image: registry, image, tag
   - Build types: nixpacks (default), dockerfile, pack
   - Required fields: company_id, project_id, display_name, source, cluster_id
4. **Provision database**:
   - Engines: PostgreSQL (9.6-17), MySQL (8.0, 9.0), MariaDB (10.4-11.1), Redis (5.0-8.x), Valkey (7.2)
   - Required: company_id, project_id, display_name, type, version, cluster_id, resource_type_id
   - Table of engine versions
5. **Create static site**: From Git, install/build commands, publish directory, node version
6. **Create object storage bucket**: Location (apac/eeur/enam/oc/weur/wnam), jurisdiction (default/eu/fedramp)
7. **Clone application**: POST /applications/{id}/clone with optional target cluster
8. **Add service to project**: POST /projects/{id}/services
9. **Find available clusters**: GET /resources/clusters
10. **Find available pod sizes**: GET /resources/process-resource-types, GET /resources/database-resource-types

Include a troubleshooting section at the bottom.

**Step 2: Commit**

```bash
git add plugins/sevalla/skills/use-sevalla/references/setup.md && git commit -m "feat: add setup.md reference — provisioning operations"
```

---

### Task 6: references/deploy.md

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/references/deploy.md`

**Step 1: Write deploy.md**

Cover all deployment operations:

1. **Trigger deployment**: POST /applications/{id}/deployments — deploy branch, docker image, or restart latest
2. **Cancel deployment**: POST /applications/{id}/deployments/{deployment_id}/cancel
3. **Rollback**: POST /applications/{id}/deployments/rollback (no body, rolls back to last successful)
4. **List deployments**: GET /applications/{id}/deployments — status values: waiting, inProgress, success, failed, cancelled, skipped
5. **Get deployment details**: GET /applications/{id}/deployments/{deployment_id}
6. **View deployment logs**: GET /applications/{id}/deployments/{deployment_id}/logs
7. **Build configuration**:
   - Nixpacks (default): auto-detect, configurable via nixpacks.toml
   - Dockerfile: custom Dockerfile path, Docker context
   - Buildpacks: builder selection, buildpack list (primary last)
   - Update via PATCH /applications/{id}: build_type, build_path, dockerfile_path, docker_context
8. **Auto-deploy settings**: PATCH /applications/{id} — auto_deploy, default_branch, wait_for_checks, allow_deploy_paths, ignore_deploy_paths
9. **Deployment hooks**: Enable/get/regenerate/disable webhook URLs for external CI triggers
10. **Pipelines**:
    - Create pipeline: POST /pipelines — type: trunk or branch
    - Add stages: POST /pipelines/{id}/stages
    - Add apps to stages: POST /pipelines/{id}/stages/{stage_id}/apps
    - Promote: POST /pipelines/{id}/promote — source_app_id → target apps
11. **Preview apps**: Enable/disable/update preview settings on pipelines
12. **Static site deployments**: POST /static-sites/{id}/deployments

Troubleshooting section: common build failures, deployment stuck, rollback strategies.

**Step 2: Commit**

```bash
git add plugins/sevalla/skills/use-sevalla/references/deploy.md && git commit -m "feat: add deploy.md reference — deployment operations"
```

---

### Task 7: references/configure.md

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/references/configure.md`

**Step 1: Write configure.md**

Cover all configuration operations:

1. **Environment variables**:
   - List: GET /applications/{id}/env-vars
   - Create: POST /applications/{id}/env-vars — key, value, is_runtime, is_buildtime
   - Update: PUT /applications/{id}/env-vars/{env_var_id}
   - Delete: DELETE /applications/{id}/env-vars/{env_var_id}
   - Variable referencing: `${key}` syntax
   - Key restrictions: a-z, 0-9, underscore only
   - Sevalla-injected variables table: SVL_COMPANY_ID, SVL_APP_ID, SVL_APP_NAME, PORT, etc.
2. **Global environment variables**: Company-wide vars deployed to all apps
3. **Custom domains**:
   - Add: POST /applications/{id}/domains — name, is_wildcard
   - DNS verification: TXT record (_cf-custom-hostname), CNAME (_acme-challenge)
   - Point via A records
   - Set primary: POST /domains/{id}/set-primary
   - Toggle system domain
   - Wildcard support (*.yourdomain.com)
   - Free SSL via Cloudflare
4. **Scaling**:
   - Vertical: PATCH process resource_type_id to change pod size
   - Horizontal manual: Set scaling_strategy to manual, instanceCount 1-50
   - Horizontal auto: Set scaling_strategy to horizontal with targetCpuPercent, min/maxInstanceCount
   - Pod size categories: Hobby, Standard (S1-S2), Memory-Optimized (M1-M3), CPU-Optimized (C1-C3)
5. **Networking**:
   - Internal connections: POST /databases/{id}/internal-connections — connect app to DB on private network
   - TCP proxies: POST /applications/{id}/tcp-proxies — expose non-HTTP services (max 3)
   - Private ports: POST /applications/{id}/private-ports
   - Toggle external DB connection: POST /databases/{id}/external-connection/toggle
6. **IP restrictions**: PUT /applications/{id}/ip-restriction — type (allow/deny), is_enabled, ip_list
7. **CDN**: POST /applications/{id}/cdn/toggle
8. **Edge cache**: POST /applications/{id}/purge-cache
9. **Health checks**: Configure liveness_probe and readiness_probe on processes (httpGet, tcpSocket, exec)
10. **Processes**:
    - Create: POST /applications/{id}/processes — type (web/worker/cron/job), entrypoint, port
    - Cron schedule: 5-field cron expression with timezone (IANA)
    - Job start policy: beforeDeployment, afterSuccessDeployment, afterFailedDeployment

Troubleshooting: domain verification failures, SSL issues, scaling constraints (persistent storage = no horizontal scaling).

**Step 2: Commit**

```bash
git add plugins/sevalla/skills/use-sevalla/references/configure.md && git commit -m "feat: add configure.md reference — configuration operations"
```

---

### Task 8: references/operate.md

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/references/operate.md`

**Step 1: Write operate.md**

Cover all observability and operations:

1. **Runtime logs**: GET /applications/{id}/runtime-logs
2. **Access logs**: GET /applications/{id}/access-logs
3. **Deployment logs**: GET /applications/{id}/deployments/{deployment_id}/logs
4. **Application metrics** (8 endpoints):
   - Requests per minute, response time, avg response time
   - Slowest requests, status codes, top status codes
   - Top countries, top pages
5. **Process metrics** (5 endpoints per process):
   - CPU usage/limit, memory usage/limit, instance count
6. **Database metrics**: CPU, memory, storage usage/limit
7. **Database backups**:
   - List: GET /databases/{id}/backups
   - Create manual: POST /databases/{id}/backups
   - Restore: POST /databases/{id}/backups/{backup_id}/restore
   - Delete: DELETE /databases/{id}/backups/{backup_id}
   - Auto daily backups (7-day retention), manual (5 max, 14-day retention)
8. **Suspend/activate**:
   - Suspend app: POST /applications/{id}/suspend
   - Activate app: POST /applications/{id}/activate
   - Same for databases
9. **Web terminal**: GET /applications/{id}/processes/{process_id}/terminal (WebSocket)
10. **Trigger cron job**: POST /applications/{id}/processes/{process_id}/trigger

**Troubleshooting triage workflow:**
- Build failures: check deployment logs → identify error → fix source → redeploy
- Runtime crashes: check runtime logs → check process metrics (OOM?) → adjust pod size or fix code
- Slow responses: check response time metrics → check slowest requests → check CPU/memory → scale
- Database issues: check DB metrics → check storage → check backups → restore if needed

**Step 2: Commit**

```bash
git add plugins/sevalla/skills/use-sevalla/references/operate.md && git commit -m "feat: add operate.md reference — observability and operations"
```

---

### Task 9: references/manage.md

**Files:**
- Create: `plugins/sevalla/skills/use-sevalla/references/manage.md`

**Step 1: Write manage.md**

Cover platform management operations:

1. **API keys**:
   - List/create/update/delete
   - Rotate: POST /api-keys/{id}/rotate (grace period for old token)
   - Toggle: POST /api-keys/{id}/toggle
   - Roles and granular capabilities
   - Expiration
2. **Webhooks**:
   - CRUD operations
   - Events: APP_CREATE, APP_UPDATE, APP_DELETE, APP_DEPLOY, DATABASE_CREATE/UPDATE/DELETE, STATIC_SITE_CREATE/UPDATE/DELETE/DEPLOY
   - Roll secret: POST /webhooks/{id}/roll-secret
   - Toggle: POST /webhooks/{id}/toggle
   - List/get deliveries for debugging
3. **Load balancers**:
   - CRUD operations
   - Destinations: add/list/delete/toggle
   - Domains: same pattern as applications
4. **Docker registries**:
   - CRUD operations
   - Registry types: dockerHub, gcr, ecr, github, gitlab, digitalOcean, custom
5. **Available resources** (read-only reference data):
   - Clusters/regions: GET /resources/clusters — 25 GCP regions
   - Database sizes: GET /resources/database-resource-types
   - Process sizes: GET /resources/process-resource-types
6. **Users**: GET /users — list company members
7. **Object storage management**:
   - CORS policies: create/update/delete
   - CDN domain: enable/disable
   - List/delete objects

**Step 2: Commit**

```bash
git add plugins/sevalla/skills/use-sevalla/references/manage.md && git commit -m "feat: add manage.md reference — platform management operations"
```

---

### Task 10: Multi-tool installer script

**Files:**
- Create: `scripts/install.sh`

**Step 1: Write install.sh**

Bash script that:
1. Detects installed AI tools by checking config directories:
   - Claude Code: `~/.claude/`
   - Cursor: `~/.cursor/`
   - OpenAI Codex: `~/.codex/`
   - OpenCode: `~/.opencode/`
2. Asks user for global vs local install
3. Clones the repo (or uses current directory if already cloned)
4. Copies `plugins/sevalla/skills/use-sevalla/` to each tool's skills directory
5. Copies hooks if applicable (Claude Code only)
6. Prints success message with next steps

**Step 2: Verify and commit**

```bash
chmod +x scripts/install.sh
bash -n scripts/install.sh
git add scripts/install.sh && git commit -m "feat: add multi-tool installer script"
```

---

### Task 11: AGENTS.md and README.md

**Files:**
- Create: `AGENTS.md`
- Create: `CLAUDE.md` (symlink to AGENTS.md)
- Create: `README.md`

**Step 1: Write AGENTS.md**

Development instructions for contributors:
- Repo structure overview
- How to add/modify skills
- Authoring guidelines (keep SKILL.md concise, references action-oriented, MCP snippets for all operations)
- Testing changes locally
- Reference file conventions

**Step 2: Create CLAUDE.md symlink**

```bash
ln -s AGENTS.md CLAUDE.md
```

**Step 3: Write README.md**

User-facing documentation:
- What this repo is
- Quick install (one-liner curl | bash)
- Manual installation for each tool
- MCP server setup instructions
- What the skill does (overview of capabilities)
- Configuration (SEVALLA_API_KEY)
- Contributing guidelines
- License

**Step 4: Commit**

```bash
git add AGENTS.md CLAUDE.md README.md && git commit -m "docs: add AGENTS.md, CLAUDE.md, and README.md"
```

---

### Task 12: Final verification

**Step 1: Verify complete structure**

```bash
find . -type f -not -path './.git/*' -not -path './.idea/*' -not -path './.claude/*' | sort
```

Expected:
```
./.claude-plugin/marketplace.json
./.gitignore
./AGENTS.md
./CLAUDE.md
./LICENSE
./README.md
./docs/plans/2026-02-28-sevalla-skills-design.md
./docs/plans/2026-02-28-sevalla-skills-plan.md
./plugins/sevalla/.claude-plugin/plugin.json
./plugins/sevalla/hooks/auto-approve-mcp.sh
./plugins/sevalla/hooks/hooks.json
./plugins/sevalla/skills/use-sevalla/SKILL.md
./plugins/sevalla/skills/use-sevalla/references/configure.md
./plugins/sevalla/skills/use-sevalla/references/deploy.md
./plugins/sevalla/skills/use-sevalla/references/manage.md
./plugins/sevalla/skills/use-sevalla/references/operate.md
./plugins/sevalla/skills/use-sevalla/references/setup.md
./plugins/sevalla/skills/use-sevalla/scripts/sevalla-api.sh
./scripts/install.sh
```

**Step 2: Verify all files have content**

```bash
wc -l plugins/sevalla/skills/use-sevalla/SKILL.md plugins/sevalla/skills/use-sevalla/references/*.md
```

Expected: SKILL.md ~200-300 lines, each reference ~150-250 lines.

**Step 3: Final commit if any changes**

```bash
git status && git log --oneline
```
