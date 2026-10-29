---
description: The project already runs its migrations in its start command, so the agent keeps that and adds no migration job.
tags: [deploy, workflow]
max_turns: 30
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Deploy this API to Sevalla in Frankfurt, with a Postgres database. The code is already pushed to GitHub.
