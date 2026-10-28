import { execFileSync } from 'node:child_process'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { basename, dirname, join, resolve } from 'node:path'

const ROOT = resolve(import.meta.dirname, '..')
const SKILL_DIR = join(ROOT, 'plugins/sevalla/skills/sevalla')
const TOOLS_FILE = join(ROOT, 'plugins/sevalla/evals/mocks/sevalla/_tools.json')
const MOCKS_DIR = join(ROOT, 'plugins/sevalla/evals')
const SPEC_URL = 'https://api.sevalla.com/v3/openapi.json'
const DOCS_INDEX_URL = 'https://docs.sevalla.com/llms.txt'
const MCP_OPERATIONS_URL = 'https://raw.githubusercontent.com/sevalla/mcp/main/src/sevalla/operations.ts'
const TOOL_SHAPE = /^(?:(?:list|get|create|trigger|rollback|search|set|delete|scale|add)_[a-z_]+|sevalla_api_[a-z]+)$/
const NOT_TOOLS = new Set(['delete_stale_apps'])

interface CliCommand {
  path: string
  options?: { long?: string }[]
  subcommands?: CliCommand[]
}

const errors: string[] = []
const fail = (message: string) => errors.push(message)

const markdownFiles = (dir: string): string[] =>
  readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = join(dir, entry.name)
    if (entry.isDirectory()) {
      return markdownFiles(full)
    }
    return entry.name.endsWith('.md') ? [full] : []
  })

const slug = (heading: string) =>
  heading
    .trim()
    .toLowerCase()
    .replace(/[`*_]/g, '')
    .replace(/[^\p{L}\p{N} -]/gu, '')
    .replace(/ /g, '-')

const anchorsOf = (text: string) =>
  new Set([...text.matchAll(/^#{1,6} (.+)$/gm)].map((m) => slug(m[1])))

const fetchText = async (url: string) => {
  const res = await fetch(url)
  if (!res.ok) {
    throw new Error(`${url} answered ${res.status}`)
  }
  return res.text()
}

const cliSchema = (): CliCommand => {
  const run = (cmd: string, args: string[]) => execFileSync(cmd, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
  try {
    return JSON.parse(run('sevalla', ['schema']))
  } catch {
    return JSON.parse(run('npx', ['-y', '@sevalla/cli@latest', 'schema']))
  }
}

const flatten = (cmd: CliCommand): CliCommand[] => [cmd, ...(cmd.subcommands ?? []).flatMap(flatten)]

const files = markdownFiles(SKILL_DIR)
const texts = new Map(files.map((f) => [f, readFileSync(f, 'utf8')]))
const rel = (f: string) => f.slice(ROOT.length + 1)

// Frontmatter and size, per the Agent Skills specification.
const skill = texts.get(join(SKILL_DIR, 'SKILL.md')) ?? ''
const frontmatter = skill.match(/^---\n([\s\S]*?)\n---\n/)?.[1] ?? ''
const name = frontmatter.match(/^name: (.+)$/m)?.[1] ?? ''
const description = frontmatter.match(/^description: (.+)$/m)?.[1] ?? ''
if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name) || name.length > 64 || name !== basename(SKILL_DIR)) {
  fail(`SKILL.md name "${name}" must be kebab-case, at most 64 characters and match its folder`)
}
if (description.length < 1 || description.length > 1024 || /[<>]/.test(description)) {
  fail(`SKILL.md description is ${description.length} characters; it must be 1 to 1024, without < or >`)
}
if (skill.split('\n').length > 500) {
  fail('SKILL.md must stay under 500 lines')
}

const versions = {
  'plugin.json': JSON.parse(readFileSync(join(ROOT, 'plugins/sevalla/.claude-plugin/plugin.json'), 'utf8')).version,
  'SKILL.md metadata': frontmatter.match(/^\s+version: "([^"]+)"$/m)?.[1],
  'README badge': readFileSync(join(ROOT, 'README.md'), 'utf8').match(/badge\/version-([\d.]+)-/)?.[1],
  'CHANGELOG.md': readFileSync(join(ROOT, 'CHANGELOG.md'), 'utf8').match(/^## v([\d.]+)/m)?.[1],
}
if (new Set(Object.values(versions)).size !== 1) {
  fail(`versions disagree: ${JSON.stringify(versions)}`)
}

const [spec, docsIndex, mcpOperations] = await Promise.all([
  fetchText(SPEC_URL),
  fetchText(DOCS_INDEX_URL),
  fetchText(MCP_OPERATIONS_URL),
])
const methods = new Map<string, string>()
for (const [path, item] of Object.entries(JSON.parse(spec).paths as Record<string, Record<string, { operationId?: string }>>)) {
  for (const [method, op] of Object.entries(item)) {
    if (op.operationId) {
      methods.set(op.operationId, method.toUpperCase())
      if (path.includes('/metrics/')) {
        methods.set(op.operationId, 'METRIC')
      }
    }
  }
}
const operationIds = new Set(methods.keys())
const additive = new Set(
  [...(mcpOperations.match(/ADDITIVE_OPERATIONS = new Set\(\[([\s\S]*?)\]\)/)?.[1] ?? '').matchAll(/'(\w+)'/g)].map((m) => m[1]),
)
const dedicated = new Map(
  [...(mcpOperations.match(/DEDICATED_TOOLS[^{]*\{([\s\S]*?)\n\}/)?.[1] ?? '').matchAll(/(\w+): '(\w+)'/g)].map((m) => [m[1], m[2]]),
)
if (additive.size === 0 || dedicated.size === 0) {
  fail(`could not read the operation classes from ${MCP_OPERATIONS_URL}`)
}
// Mirrors classify() in the MCP server: which generic tool runs an operation, or which dedicated tool owns it.
const toolFor = (id: string) => {
  const method = methods.get(id)
  if (dedicated.has(id) || method === 'METRIC') {
    return dedicated.get(id) ?? 'get_metrics'
  }
  if (method === 'GET') {
    return 'sevalla_api_read'
  }
  if (method === 'DELETE') {
    return 'sevalla_api_delete'
  }
  return additive.has(id) ? 'sevalla_api_create' : 'sevalla_api_update'
}
const docPages = new Set([...docsIndex.matchAll(/https:\/\/docs\.sevalla\.com\/([^\s)]+?)\.md\b/g)].map((m) => m[1]))
const tools = new Set<string>(JSON.parse(readFileSync(TOOLS_FILE, 'utf8')).tools.map((t: { name: string }) => t.name))
const cli = flatten(cliSchema())
const cliByPath = new Map(cli.map((c) => [c.path, c]))
const globalFlags = new Set(['--json', '--api-url', '--help', '--version', '--confirm'])

for (const [file, text] of texts) {
  for (const [, id] of text.matchAll(/\b([a-z][A-Za-z]+V3)\b/g)) {
    if (!operationIds.has(id)) {
      fail(`${rel(file)}: operation ${id} is not in ${SPEC_URL}`)
    } else if (!toolFor(id).startsWith('sevalla_api_')) {
      fail(`${rel(file)}: ${id} only runs through \`${toolFor(id)}\`; name that tool instead`)
    }
  }

  for (const line of text.split('\n')) {
    const generic = new Set(line.match(/sevalla_api_(?:read|create|update|delete)/g))
    if (generic.size !== 1) {
      continue
    }
    const [tool] = generic
    for (const [, id] of line.matchAll(/\b([a-z][A-Za-z]+V3)\b/g)) {
      if (operationIds.has(id) && toolFor(id) !== tool) {
        fail(`${rel(file)}: ${id} runs on \`${toolFor(id)}\`, not \`${tool}\``)
      }
    }
  }

  for (const [, token] of text.matchAll(/`([a-z_]+)`/g)) {
    if (TOOL_SHAPE.test(token) && !NOT_TOOLS.has(token) && !tools.has(token)) {
      fail(`${rel(file)}: \`${token}\` looks like an MCP tool but the server has no such tool`)
    }
  }

  for (const [, path] of text.matchAll(/https:\/\/docs\.sevalla\.com\/([^\s)`#]+)/g)) {
    const page = path.replace(/[.,;:]+$/, '').replace(/\.md$/, '')
    if (page !== 'llms.txt' && !docPages.has(page)) {
      fail(`${rel(file)}: docs page ${page} is not in ${DOCS_INDEX_URL}`)
    }
  }

  for (const [, target, anchor] of text.matchAll(/\]\(((?!https?:)[^)#\s]*)(?:#([^)\s]+))?\)/g)) {
    const targetFile = target ? resolve(dirname(file), target) : file
    if (!existsSync(targetFile)) {
      fail(`${rel(file)}: link to missing file ${target}`)
    } else if (anchor && !anchorsOf(readFileSync(targetFile, 'utf8')).has(anchor)) {
      fail(`${rel(file)}: link to missing anchor ${target}#${anchor}`)
    }
  }

  const commandLines = [...text.matchAll(/^[ \t]*(sevalla [^\n]+)$/gm), ...text.matchAll(/`(sevalla [^`]+)`/g)].map(
    (m) => m[1],
  )
  for (const line of commandLines) {
    const words = line.split(/\s+/)
    let command: CliCommand | undefined
    for (let n = words.length; n > 0 && !command; n--) {
      command = cliByPath.get(words.slice(0, n).join(' '))
    }
    if (!command || command.path === 'sevalla') {
      fail(`${rel(file)}: no CLI command for "${line}"`)
      continue
    }
    const known = new Set([...globalFlags, ...(command.options ?? []).map((o) => o.long)])
    for (const flag of line.match(/(?<=\s)--[a-z-]+/g) ?? []) {
      if (!known.has(flag)) {
        fail(`${rel(file)}: "${command.path}" has no ${flag} flag`)
      }
    }
  }
}

for (const mock of markdownFiles(MOCKS_DIR).filter((f) => f.includes('/mocks/sevalla/'))) {
  const tool = basename(mock, '.md')
  if (!tool.startsWith('_') && !tools.has(tool)) {
    fail(`${rel(mock)}: mocks a tool the server doesn't have`)
  }
}

if (errors.length > 0) {
  console.error(errors.map((e) => `✗ ${e}`).join('\n'))
  console.error(`\n${errors.length} problem(s)`)
  process.exit(1)
}
console.log(`✓ ${files.length} skill files: operation IDs, tool names, CLI commands, docs links and anchors check out`)
