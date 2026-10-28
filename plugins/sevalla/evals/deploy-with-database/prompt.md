---
description: A first deploy that needs a database must create the app without deploying, connect the database, run migrations before deployment, then deploy once.
tags: [deploy, workflow]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Deploy this API to Sevalla in Frankfurt, with a Postgres database. The code is already pushed to GitHub.
