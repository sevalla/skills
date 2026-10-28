# Frameworks on Sevalla

Every framework needs the same four things. The table below lists only what differs.

1. **Listen on `0.0.0.0` and the port in `PORT`.** Sevalla sets `PORT` to the web process's port,
   8080 by default. A server bound to `localhost` or `127.0.0.1` can't be reached.
2. **Pin the runtime.** `engines.node` in `package.json` (Nixpacks installs Node.js 22 otherwise),
   `.python-version`, `.ruby-version`, `go.mod`. Static sites ignore these: their version is the
   site's `node_version`.
3. **Migrations in a `job` process** with `job_start_policy: "beforeDeployment"`
   ([deploy.md](deploy.md#processes-workers-cron-jobs-and-migrations)), not in the build: the build
   can't reach the database.
4. **Build-time variables before the build.** Values the build inlines into the bundle
   (`NEXT_PUBLIC_*`, `VITE_*`, `PUBLIC_*`) only reach builds that start after you set them.

Nixpacks, the default builder, detects the language from the lockfile and the manifest. Commit the
lockfile. You rarely need a Dockerfile.

| Framework | Product | Start command | What to check | Guide |
| --- | --- | --- | --- | --- |
| Next.js (SSR, API routes, server actions) | Application | `next start` | Reads `PORT` itself. Pin `engines.node` (`"24.x"`). Leave `output` unset; `standalone` is for a Dockerfile build | [nextjs](https://docs.sevalla.com/guides/javascript/nextjs.md) |
| Next.js with `output: "export"` | Static site | none | Publish directory `out`. No API routes or server actions | same |
| Vite, React, Vue or Svelte SPA | Static site | none | Publish directory `dist`. `_redirects` with `/*    /index.html    200` for client-side routing | [static sites](https://docs.sevalla.com/static-sites/build-settings.md) |
| Astro (static, the default) | Static site | none | Publish directory `dist` | [astro](https://docs.sevalla.com/guides/javascript/astro.md) |
| Astro with on-demand pages | Application | `node ./dist/server/entry.mjs` | `@astrojs/node` adapter in `standalone` mode, `output: "server"`, and `server: { host: true }`, or it listens on `localhost` and returns 502 | same |
| Nuxt | Application | `node .output/server/index.mjs` | `nuxt generate` instead gives a static site from `.output/public` | [nuxt](https://docs.sevalla.com/guides/javascript/nuxt.md) |
| SvelteKit | Application | `node build` | Replace `adapter-auto` with `@sveltejs/adapter-node` | [sveltekit](https://docs.sevalla.com/guides/javascript/sveltekit.md) |
| Remix | Application | the framework's Node server | Bound to `PORT` | [remix](https://docs.sevalla.com/guides/javascript/remix.md) |
| TanStack Start | Application | `node .output/server/index.mjs` | Set the build-time variable `NIXPACKS_SPA_CADDY=false`, or Nixpacks serves it as a single-page app | [tanstack-start](https://docs.sevalla.com/guides/javascript/tanstack-start.md) |
| Express, Fastify, NestJS | Application | `node dist/main.js` or `npm start` | `app.listen(process.env.PORT \|\| 8080, "0.0.0.0")`. Fastify defaults to `localhost`: pass `host: "0.0.0.0"` | [express](https://docs.sevalla.com/guides/javascript/express.md), [fastify](https://docs.sevalla.com/guides/javascript/fastify.md), [nestjs](https://docs.sevalla.com/guides/javascript/nestjs.md) |
| Bun | Application | `bun run index.ts` | `Bun.serve()` reads `PORT` and binds `0.0.0.0`. Commit `bun.lock` | [bun](https://docs.sevalla.com/guides/javascript/bun.md) |
| Deno 2 | Application, `build_type: "dockerfile"` | the Dockerfile's `CMD` | Nixpacks installs Deno 1.36, which can't run Deno 2: build from a Dockerfile on the `denoland/deno` image. Read `PORT` | [deno](https://docs.sevalla.com/guides/javascript/deno.md) |
| Turborepo or another workspace monorepo | One application per app | `NIXPACKS_START_CMD`, for example `pnpm --filter web start` | Build from the repository root (no `build_path`, which drops the root lockfile and shared packages) with `NIXPACKS_BUILD_CMD` filtered to the app (`pnpm turbo run build --filter=web`), both as variables. Deploy paths keep a push from deploying every app; they don't work with Bitbucket | [turborepo](https://docs.sevalla.com/guides/javascript/turborepo.md) |
| Django | Application | `gunicorn <project>.wsgi --bind 0.0.0.0:$PORT` | `collectstatic` in the build (whitenoise serves the files); `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` from variables that include the `sevalla.app` domain and any custom domain | [django](https://docs.sevalla.com/guides/python/django/deploy.md) |
| FastAPI | Application | `fastapi run <path>/main.py --port $PORT --forwarded-allow-ips '*'` | Alembic migrations in a `beforeDeployment` job | [fastapi](https://docs.sevalla.com/guides/python/fastapi/deploy.md) |
| Flask | Application | `gunicorn <module>:app --bind 0.0.0.0:$PORT` | | [flask](https://docs.sevalla.com/guides/python/flask/deploy.md) |
| Laravel or other PHP | Application | the Nixpacks default (nginx and PHP-FPM) | `APP_KEY` as a variable; `php artisan migrate --force` in a `beforeDeployment` job | [nixpacks](https://docs.sevalla.com/applications/builds/nixpacks.md) |
| Ruby on Rails | Application | `bundle exec rails server -b 0.0.0.0 -p $PORT` | `RAILS_ENV=production`, `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`; `rails db:migrate` in a `beforeDeployment` job | [nixpacks](https://docs.sevalla.com/applications/builds/nixpacks.md) |
| Go | Application | the built binary | Read the port from `PORT` | [nixpacks](https://docs.sevalla.com/applications/builds/nixpacks.md) |
| Anything with a production Dockerfile | Application | the image's `CMD` | `build_type: "dockerfile"`, image for `linux/amd64`, the server on `PORT` | [dockerfile](https://docs.sevalla.com/applications/builds/dockerfile.md) |

Moving from Heroku: Nixpacks starts the `Procfile`'s `web` line as the web process, but Sevalla
creates no other process from it: create each one yourself (`createProcessV3`). Each other
long-running line becomes a `worker`, Scheduler and clock entries a `cron`, and add-ons Sevalla
databases. Move the `release` line into a `beforeDeployment` job and delete it from the
`Procfile`: Nixpacks would run it during the build, where the database can't be reached. See
https://docs.sevalla.com/guides/migrate-from-heroku.md.

**Background work** goes in a `worker` process (always on) or a `cron` process (on a schedule) of
the same application: they share its build and variables.

**Files that must survive a restart** go to object storage or a database. A disk
([production.md](production.md#disks)) keeps its process to one instance.
