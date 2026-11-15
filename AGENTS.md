# Sevalla agent skills: development guide

How to change the `sevalla` skill and keep it correct. People and agents both work here.

## Layout

```
.claude-plugin/marketplace.json     Claude Code marketplace: one plugin, ./plugins/sevalla
plugins/sevalla/
  .claude-plugin/plugin.json        Plugin manifest: name, version, listing fields
  .mcp.json                         The Sevalla MCP server (https://mcp.sevalla.com/mcp)
  README.md                         The plugin directory listing: what the plugin runs and sends
  assets/icon.png                   Listing icon, from the brand kit (social/avatar.png)
  skills/sevalla/
    SKILL.md                        Rules, interface choice, the deploy and debug workflows, routing
    references/                     Opened on demand: deploy, frameworks, troubleshooting,
                                    production, operations, cli
  evals/                            claude plugin eval cases; mocks/sevalla holds the MCP mocks
```

Only Markdown, text, JSON, YAML and images go in this repository: the Claude plugin directory
refuses scripts and programs from organizations that aren't verified. The check script, its CI
job, and the eval cases that build a project with a bash script live in [sevalla/skills-dev](https://github.com/sevalla/skills-dev),
cloned next to this repository.

## What the skill is for

The MCP server already describes its tools and every API operation, and the docs describe the
platform. The skill adds what neither can: reading the user's code before a deploy, choosing
the right product and operation, the order of a workflow, Sevalla facts an agent needs before it
acts, and the safety rules. Don't copy API reference or docs pages into it: link them, or name the
operation ID.

## Writing rules

- **SKILL.md** stays under 500 lines (it's under 200). The rules come first: after compaction,
  only the start of a skill is kept.
- **References** are one level deep, linked from SKILL.md, each with a contents list when it runs
  past 100 lines.
- Name MCP tools without a prefix (`trigger_deployment`): the prefix depends on how the server is
  connected. Name other operations by operation ID (`cloneApplicationV3`).
- Every fact comes from docs.sevalla.com, the OpenAPI spec, the MCP server's source or the CLI's
  schema. These sometimes disagree, and spec and tool descriptions have been wrong (a clone
  doesn't deploy; non-HTTP probes are dropped): when it matters, check what the API actually does,
  and report the mismatch to whoever owns the wrong text.
- Name the generic tool that runs an operation exactly as the MCP server classifies it: most
  `POST` operations run on `sevalla_api_update`, even when their ID starts with `create`.
  `check.ts` enforces this.
- Write in Sevalla's voice, as the brand guidelines in [sevalla/brandkit](https://github.com/sevalla/brandkit) describe:
  plain words, sentence case, no emoji, example names such as `storefront` and `shop.example.com`.
- No `allowed-tools` in the frontmatter: it pre-approves tools, which would let destructive calls
  skip the user's confirmation.

## Check your change

```sh
node ../skills-dev/scripts/check.ts
claude plugin validate plugins/sevalla
claude plugin validate .
```

`check.ts` fails when an operation ID isn't in the live spec, a line pairs an operation with a
generic tool that doesn't run it (per the MCP server's `operations.ts`), the skill names an
operation only a dedicated tool runs, a tool name isn't in `evals/mocks/sevalla/_tools.json`, a
`sevalla` command or flag isn't in the CLI's schema, a docs.sevalla.com page isn't in `llms.txt`,
a relative link or anchor is broken, or the version numbers disagree. It proves that names exist
and match, not that every sentence about them is true. It needs Node.js 24 and network access,
and uses `sevalla schema` when the CLI is installed, or `npx @sevalla/cli` otherwise. CI runs it
in skills-dev every Monday, not on pushes here, so run it before you push.

When the MCP server's tools change, refresh `_tools.json` from its `tools/list` response, for
example by running the server in stdio mode from its repository:

```sh
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"skills","version":"0"}}}' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | SEVALLA_API_KEY=unused node src/index.ts --stdio
```

## Evals

Each case in `plugins/sevalla/evals/` is a prompt, graders, and fixed answers for the MCP tools it
needs, so runs never reach a Sevalla account. Cases that build a small project in the workspace
first need a `scaffold.sh`, so they live in skills-dev: copy them in before a run, as its README
shows (`.gitignore` keeps them out of commits here). Every other tool answers from `evals/mocks/sevalla/`: read tools with the MCP
server's real `404` message, write tools with a plausible success, so a "must not call" grader can
fail. Keep mock answers in the real tools' format (capture them from the MCP server running against
its fake API, `test/support/fake-api.ts` in the MCP repository), and don't put the answer in a field
the real tool doesn't have.

The comparison that matters is the skill against the MCP server alone. `claude plugin eval`'s
default baseline runs without the plugin, and so without the MCP server too. Run the suite twice
and compare:

```sh
claude plugin eval plugins/sevalla --ablation none --scaffold --allow-tools Edit Write --judge-model sonnet
claude plugin eval plugins/sevalla --ablation none --scaffold --allow-tools Edit Write --judge-model sonnet --disallow-tools Skill
```

Add `--model haiku` or `--model sonnet` to check smaller models. Without the skills-dev cases
copied in, `--scaffold` has nothing to run and the suite covers 6 of the 11 cases. Each run is a real model call on
your account. A good new case is one the MCP server alone gets wrong: write it from a real support
case or a failed agent session, and check that it fails with `--disallow-tools Skill` before you
change the skill to fix it.

## Release

Bump `version` in `plugins/sevalla/.claude-plugin/plugin.json`, in the skill's `metadata`, in the
README's version badge, and add the release to `CHANGELOG.md` (`check.ts` fails when they
disagree). Tags are `vX.Y.Z`.
