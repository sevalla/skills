# Frameworks on Sevalla

Every framework needs the same four things. The table below lists only what differs.

1. **Listen on `0.0.0.0` and the port in `PORT`.** Sevalla sets `PORT` to the web process's port,
   8080 by default. A server bound to `localhost` or `127.0.0.1` can't be reached.
2. **Pin the runtime.** `engines.node` in `package.json` (Ingot builds on its newest line otherwise),
   `.python-version`, `.ruby-version`, `go.mod`. Static sites ignore these: their version is the
   site's `node_version`.
3. **Migrations where the project runs them.** Keep its way: the start command, the build, CI or
   by hand. A build can't reach a Sevalla database over the private network, so migrations in the
   build only work against a database it can reach. When the project has migrations and nothing
   runs them on deploy, a `job` process with `job_start_policy: "beforeDeployment"` does
   ([deploy.md](deploy.md#processes-workers-cron-jobs-and-migrations)).
4. **Build-time variables before the build.** Values the build inlines into the bundle
   (`NEXT_PUBLIC_*`, `VITE_*`, `PUBLIC_*`) only reach builds that start after you set them.

Ingot, the default builder, detects the language, framework, runtime version, package manager and
start command, and writes a Dockerfile for the app. Commit the lockfile: installs hold to it. You
rarely need a Dockerfile of your own. The start commands below are what runs; Ingot usually
detects them, so set one only when it doesn't.

- **Override what it detects** with the web process's start command, an `ingot.json` in the build
  path, or `INGOT_*` variables available at build time: `INGOT_START_CMD`, `INGOT_BUILD_CMD`,
  `INGOT_NODE_VERSION` (`INGOT_<LANGUAGE>_VERSION`), `INGOT_RUN_PACKAGES` for Debian packages the
  app needs at runtime. It doesn't read `nixpacks.toml` or `NIXPACKS_*` variables.
- **The app runs as user `1000:1000`**, from `/app`: it can write only to `/app` and `/tmp`, and
  can't install packages at runtime.
- **The build log starts with Ingot's plan**: each decision and the file it came from. A line
  starting with `!` is a warning, one starting with `✗` the reason the build stopped.

| Framework | Product | Start command | What to check | Guide |
| --- | --- | --- | --- | --- |
| Next.js (SSR, API routes, server actions) | Application | `next start` | Reads `PORT` itself. Pin `engines.node` (`"24.x"`) | [nextjs](https://docs.sevalla.com/guides/javascript/nextjs.md) |
| Next.js with `output: "export"` | Static site | none | Publish directory `out`. No API routes or server actions | same |
| Vite, React, Vue or Svelte SPA | Static site | none | Publish directory `dist`. `_redirects` with `/*    /index.html    200` for client-side routing | [static sites](https://docs.sevalla.com/static-sites/build-settings.md) |
| Astro (static, the default) | Static site | none | Publish directory `dist` | [astro](https://docs.sevalla.com/guides/javascript/astro.md) |
| Astro with on-demand pages | Application | `node ./dist/server/entry.mjs` | `@astrojs/node` adapter in `standalone` mode (`middleware` mode has no server to start), `output: "server"` | same |
| Nuxt | Application | `node .output/server/index.mjs` | `nuxt generate` instead gives a static site from `.output/public` | [nuxt](https://docs.sevalla.com/guides/javascript/nuxt.md) |
| SvelteKit | Application | `node build` | Replace `adapter-auto` with `@sveltejs/adapter-node` | [sveltekit](https://docs.sevalla.com/guides/javascript/sveltekit.md) |
| Remix | Application | the framework's Node server | Bound to `PORT` | [remix](https://docs.sevalla.com/guides/javascript/remix.md) |
| TanStack Start | Application | `node .output/server/index.mjs` | Add Nitro (`nitro` in the dependencies, `nitro()` in `vite.config`'s plugins): without it the build has no server to start | [tanstack-start](https://docs.sevalla.com/guides/javascript/tanstack-start.md) |
| Express, Fastify, NestJS | Application | `node dist/main.js` or `npm start` | `app.listen(process.env.PORT \|\| 8080, "0.0.0.0")`. Fastify defaults to `localhost`: pass `host: "0.0.0.0"` | [express](https://docs.sevalla.com/guides/javascript/express.md), [fastify](https://docs.sevalla.com/guides/javascript/fastify.md), [nestjs](https://docs.sevalla.com/guides/javascript/nestjs.md) |
| Bun | Application | `bun run index.ts` | `Bun.serve()` reads `PORT` and binds `0.0.0.0`. Commit `bun.lock` | [bun](https://docs.sevalla.com/guides/javascript/bun.md) |
| Deno 2 | Application | the `start` task in `deno.json`, or `main.ts` | Read `PORT`. A `deno serve` task needs `--allow-net` or `--port $PORT` | [deno](https://docs.sevalla.com/guides/javascript/deno.md) |
| Turborepo or another workspace monorepo | One application per app | the app's own `start` script | Build from the repository root (no `build_path`, which drops the root lockfile and shared packages) with the build-time variable `INGOT_APP` set to the app's folder (`apps/web`): Ingot installs at the root and builds the app with Turborepo or Nx. Deploy paths keep a push from deploying every app; they don't work with Bitbucket | [turborepo](https://docs.sevalla.com/guides/javascript/turborepo.md) |
| Django | Application | `gunicorn <project>.wsgi --bind 0.0.0.0:$PORT` | `gunicorn` in the dependencies; `collectstatic` in the build (whitenoise serves the files); `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` from variables that include the `sevalla.app` domain and any custom domain | [django](https://docs.sevalla.com/guides/python/django/deploy.md) |
| FastAPI | Application | `fastapi run <path>/main.py --port $PORT --forwarded-allow-ips '*'` | `uvicorn` or `fastapi[standard]` in the dependencies; Alembic migrations (point 3) | [fastapi](https://docs.sevalla.com/guides/python/fastapi/deploy.md) |
| Flask | Application | `gunicorn <module>:app --bind 0.0.0.0:$PORT` | `gunicorn` in the dependencies | [flask](https://docs.sevalla.com/guides/python/flask/deploy.md) |
| Laravel or other PHP | Application | FrankenPHP, which Ingot sets up | `APP_KEY` as a variable; `php artisan migrate --force` (point 3). Commit `composer.lock` | [builds](https://docs.sevalla.com/applications/builds/overview.md) |
| Ruby on Rails | Application | `bundle exec rails server -b 0.0.0.0 -p $PORT` | `puma` in the `Gemfile`; `RAILS_ENV=production`, `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`; `rails db:migrate` (point 3) | [builds](https://docs.sevalla.com/applications/builds/overview.md) |
| Go | Application | the built binary | Read the port from `PORT` | [builds](https://docs.sevalla.com/applications/builds/overview.md) |
| Anything with a production Dockerfile | Application | the image's `CMD` | `build_type: "dockerfile"`, image for `linux/amd64`, the server on `PORT` | [dockerfile](https://docs.sevalla.com/applications/builds/dockerfile.md) |

Moving from Heroku: Ingot starts the `Procfile`'s `web` line as the web process, but Sevalla
creates no other process from it: create each one yourself (`createProcessV3`). Each other
long-running line becomes a `worker`, Scheduler and clock entries a `cron`, and add-ons Sevalla
databases. Ingot doesn't run the `release` line: move it into a `beforeDeployment` job. See
https://docs.sevalla.com/guides/migrate-from-heroku.md.

**Background work** goes in a `worker` process (always on) or a `cron` process (on a schedule) of
the same application: they share its build and variables.

**Files that must survive a restart** go to object storage or a database. A disk
([production.md](production.md#disks)) keeps its process to one instance.
