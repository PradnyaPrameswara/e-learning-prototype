# Project-Local Agent Tooling

Research and verification date: **2026-09-24**. This setup is scoped to this repository. It does not change user-level Codex, editor, Claude, OpenCode, or npm configuration.

## Tool Inventory

| Tool                     | Type                                                 | Purpose                                                                                           | Project-local integration                                            | Auto-use?                                | Verification                                                          |
| ------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- | ---------------------------------------- | --------------------------------------------------------------------- |
| Matt Pocock Skills       | Agent skill collection                               | Requirements, domain alignment, implementation, TDD, debugging, handoff, architecture improvement | `.agents/skills/`; installed for Codex with Skills CLI               | No; choose one relevant skill            | Codex loaded `grill-me`; skills CLI reports project scope             |
| Addy Osmani Agent Skills | Agent skill collection                               | API, frontend, security, performance, shipping, and review practices                              | `.agents/skills/` plus required `.agents/references/`                | No; complementary skills only            | Codex loaded `code-review-and-quality`                                |
| CodeDB                   | MCP/code-intelligence context engine                 | Repository context, symbol definitions, callers, outlines, call paths                             | `.tools/codedb/`, `.codex/config.toml`, local launcher               | Lazy/on-demand                           | MCP handshake, context query, `Env` symbol query                      |
| Lexa                     | MCP/code graph, retrieval, dependency tracing, audit | Impact tracing and graph/audit questions                                                          | `.tools/lexa/`, `.codex/config.toml`, local launcher                 | On demand; use when impact/graph matters | MCP brief, symbol, outline, dependency trace, audit                   |
| anti-slop                | Lint/static-analysis tooling                         | Opinionated TypeScript/JavaScript checks for selected code-quality patterns                       | Local skill, vendored Oxlint plugin, `oxlint.config.ts`, `pnpm lint` | Yes, through lint and CI                 | Real Oxlint run over project source                                   |
| Caveman                  | Token-efficiency skill                               | Reduce low-value prose and repetitive summaries                                                   | `.agents/skills/caveman/`                                            | Selectively                              | Codex read and applied the local skill to a harmless file explanation |
| LSP-AI                   | Editor/LSP tooling                                   | Optional editor language-server assistance                                                        | `.tools/lsp-ai/` and `.codex/lsp-ai-initialization.json`             | No; editor-owned                         | Version/help and LSP `initialize` handshake; no model call            |

## Verified Smoke Results

```text
MATT_GRILL_ME_AVAILABLE: YES
MATT_GRILL_WITH_DOCS_AVAILABLE: YES
MATT_SHOW_ME_NATIVE: NO
MATT_SMOKE_TEST: PASS (Codex loaded grill-me and asked one focused clarification)
ADDY_SMOKE_TEST: PASS (Codex loaded code-review-and-quality and returned its five review dimensions)

CODEDB_INSTALLED: YES
CODEDB_PROJECT_SCOPED: YES
CODEDB_MCP_DISCOVERED: YES
CODEDB_INDEX_OK: YES
CODEDB_CONTEXT_OK: YES
CODEDB_SYMBOL_QUERY_OK: YES (`Env`)

LEXA_INSTALLED: YES
LEXA_PROJECT_SCOPED: YES
LEXA_MCP_DISCOVERED: YES
LEXA_INDEX_OK: YES
LEXA_BRIEF_OK: YES
LEXA_SYMBOL_OK: YES (`Env`)
LEXA_TRACE_DEPS_OK: YES
LEXA_AUDIT_OK: YES (advisory findings documented below)

ANTI_SLOP_SKILL_INSTALLED: YES
ANTI_SLOP_VENDORED: YES
OXlint_VERSION: 1.85.0
ANTI_SLOP_RULES_ENABLED: YES (all upstream rules except the two documented overrides)
ANTI_SLOP_RULES_CUSTOMIZED: YES (two documented overrides)
ANTI_SLOP_VALIDATION: PASS

CAVEMAN_SKILL_INSTALLED: YES
CAVEMAN_PROJECT_LOCAL: YES
CAVEMAN_GLOBAL_PROXY_INSTALLED: NO
CAVEMAN_INVOCATION_TEST: PASS

LSP_AI_INSTALLED: YES
LSP_AI_PROJECT_RUNTIME: YES
LSP_AI_CONFIG_VALID: YES
LSP_AI_LSP_HANDSHAKE: PASS
LSP_AI_PROVIDER_CONFIGURED: NO
GLOBAL_SETUP_REQUIRED: NO (optional; no editor selected; configure a project-scoped editor client if used)

PROJECT_MCP_CONFIG: .codex/config.toml
GLOBAL_CODEX_CONFIG_CHANGED: NO
```

Codex project MCP discovery was verified from this repository; `codedb_elearning` and `lexa_elearning` were absent when Codex was queried from outside this repository. Existing user-level MCP entries were read only and left unchanged.

## Source and Installation Records

All GitHub revisions below were inspected from the upstream source before installation. “Project files” includes local skills, configuration, launchers, vendored policy, and deterministic installer scripts. Downloaded executables, indexes, and caches remain ignored under `.tools/`.

### Matt Pocock Skills

- `UPSTREAM_SOURCE`: [mattpocock/skills](https://github.com/mattpocock/skills)
- `UPSTREAM_REVISION_OR_VERSION`: `c55ee46073ed923f86ce59a5eb3b6d895095d1b7`; Skills CLI `1.7.0`
- `INSTALL_METHOD`: `npx skills@1.7.0 add mattpocock/skills --agent codex --skill ...`, with process-local npm cache under `.tools/npm-cache`; project setup run using the repository's existing GitHub issue, `docs/`, planning-contract, and Git workflow conventions.
- `PROJECT_FILES_CREATED`: `.agents/skills/{setup-matt-pocock-skills,grill-with-docs,grill-me,to-spec,implement,tdd,diagnosing-bugs,improve-codebase-architecture,handoff,grilling,domain-modeling,codebase-design}/`, `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, `AGENTS.md`, `skills-lock.json`
- `PROJECT_FILES_MODIFIED`: Matt's local `implement/SKILL.md` routes the primary review to Addy and preserves the repository issue/branch/PR/human-merge process.
- `GLOBAL_STATE_MODIFIED`: `NO`
- `MATT_GRILL_ME_AVAILABLE`: `YES`
- `MATT_GRILL_WITH_DOCS_AVAILABLE`: `YES`
- `MATT_SHOW_ME_NATIVE`: `NO`; the pinned Matt repository references `show-me` as an external HumanLayer skill. It was not installed.

Installed workflow skills are `grill-with-docs`, `grill-me`, `to-spec`, `implement`, `tdd`, `diagnosing-bugs`, `improve-codebase-architecture`, and `handoff`, with their required local dependencies. `setup-matt-pocock-skills` remains available for future setup reference. `ask-matt`, `to-tickets`, and Matt's `code-review` were evaluated but not installed: `ask-matt` is a meta-router duplicating this routing guide; `to-tickets` assumes multi-ticket/tracer workflows that do not match this repository's focused just-in-time issues; Matt's review skill delegates parallel reviews and would duplicate the selected Addy review workflow. The local `implement` skill is intentionally adapted to this repository and is not a verbatim upstream copy.

### Addy Osmani Agent Skills

- `UPSTREAM_SOURCE`: [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
- `UPSTREAM_REVISION_OR_VERSION`: `bcab6a1b8503100e8618c3b4e32cc78de43de769`; Skills CLI `1.7.0`
- `INSTALL_METHOD`: `npx skills@1.7.0 add addyosmani/agent-skills --agent codex --skill ...`, with process-local npm cache under `.tools/npm-cache`; required shared references copied as documented by upstream.
- `PROJECT_FILES_CREATED`: `.agents/skills/{api-and-interface-design,code-review-and-quality,frontend-ui-engineering,performance-optimization,security-and-hardening,shipping-and-launch}/`, `.agents/references/{accessibility-checklist.md,definition-of-done.md,performance-checklist.md,security-checklist.md}`
- `PROJECT_FILES_MODIFIED`: `skills-lock.json`
- `GLOBAL_STATE_MODIFIED`: `NO`

Addy's `/spec`, `/plan`, `/build`, `/test`, `/constraints`, `/review`, `/code-simplify`, `/ship`, and `/webperf` are upstream workflow entrypoints, not installed Codex skill directories. The directly useful skills were selected instead. Addy's `interview-me`, planning/spec, and TDD equivalents were evaluated but not installed because Matt skills and the repository's issue-first process already cover those stages. Shared reference files are present because upstream documents that single-skill installation does not include all root references automatically.

### CodeDB

- `UPSTREAM_SOURCE`: [justrach/codedb](https://github.com/justrach/codedb)
- `UPSTREAM_REVISION_OR_VERSION`: repository `55483a05624b4b0ebaf5d02ca339ad48fd7c376e`; release `v0.2.5856`
- `INSTALL_METHOD`: `scripts/tooling/install-agent-tools.ps1` downloads the official Windows x64 release and verifies its SHA-256 against the release `checksums.sha256` manifest.
- `PROJECT_FILES_CREATED`: `.codex/config.toml`, `scripts/tooling/install-agent-tools.ps1`, `scripts/tooling/launch-codedb-mcp.ps1`; executable and project index are in ignored `.tools/codedb/`.
- `PROJECT_FILES_MODIFIED`: `.gitignore`
- `GLOBAL_STATE_MODIFIED`: `NO`
- `CODEDB_SHA256`: `78f64df9b565d1c8e204bdd81a374b08291a8dcda18a21297d96dc9e331821ba` (matches upstream release manifest)

The launcher confines the home/cache to this checkout, disables telemetry and automatic semantic migration, and enables CodeDB's documented lazy MCP mode. Lazy startup is an upstream experimental feature. CodeDB is a context aid, not an editing or correctness authority. The index is scoped to this repository.

### Lexa

- `UPSTREAM_SOURCE`: [anvia-hq/lexa](https://github.com/anvia-hq/lexa)
- `UPSTREAM_REVISION_OR_VERSION`: repository `39974f24d586ec9d73fa3dc36ad888f21c2f7ed3`; release `v0.10.1`
- `INSTALL_METHOD`: `scripts/tooling/install-agent-tools.ps1` downloads the official Windows x64 release and verifies SHA-256 against upstream `SHA256SUMS`.
- `PROJECT_FILES_CREATED`: `scripts/tooling/launch-lexa-mcp.ps1`; project graph is ignored at `.tools/lexa/index.sqlite`.
- `PROJECT_FILES_MODIFIED`: `.codex/config.toml`, `.gitignore`
- `GLOBAL_STATE_MODIFIED`: `NO`
- `LEXA_SHA256`: `ab2b786c90fe5fa6220a1edc149ac8ffe6ec3d6c7a2c2aef0838a7ae8ca2fe7e` (matches upstream release manifest)

Lexa's upstream repository was archived by its owner on 2026-08-18. Keep the binary pinned; review maintenance/security status before upgrading. Its graph/audit output is advisory. The smoke audit reported an unresolved import in vendored policy code and a large existing constraint-check function; these are known graph/audit limitations, not grounds to change unrelated code.

### anti-slop

- `UPSTREAM_SOURCE`: [dmmulroy/anti-slop](https://github.com/dmmulroy/anti-slop)
- `UPSTREAM_REVISION_OR_VERSION`: repository `c44ef22ca116d0ba62a3ff663a0bd13a3f3fa40b`; `oxlint` and `@oxlint/plugins` `1.85.0`
- `INSTALL_METHOD`: installed the upstream `install-anti-slop` skill locally, then used it to vendor the upstream JavaScript plugin and provenance under `tools/oxlint/anti-slop/`.
- `PROJECT_FILES_CREATED`: `.agents/skills/install-anti-slop/`, `tools/oxlint/anti-slop/`, `oxlint.config.ts`
- `PROJECT_FILES_MODIFIED`: root `package.json`, `pnpm-lock.yaml`, `.prettierignore`; the existing root `lint` command invokes `lint:anti-slop`, so existing CI now runs it without a separate workflow.
- `GLOBAL_STATE_MODIFIED`: `NO`
- `ANTI_SLOP_RULES_ENABLED`: upstream rules are enabled as errors in `oxlint.config.ts`, together with `oxc/no-accumulating-spread`.
- `ANTI_SLOP_RULES_CUSTOMIZED`: `anti-slop/no-unknown-parameters` is off because the Worker JSON helper intentionally serializes an `unknown` value without inspecting it. `anti-slop/require-readable-spacing` is off because Prettier owns formatting and the rule would reformat valid Foundation code broadly. Rationale is inline and summarized in `tools/oxlint/anti-slop/UPSTREAM.md`.

Do not blanket-apply anti-slop autofixes. Project architecture and explicit constraints outrank upstream stylistic opinions. Oxlint JS plugin support is documented as alpha, so pin matching Oxlint/plugin versions and reverify during dependency updates.

### Caveman

- `UPSTREAM_SOURCE`: [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)
- `UPSTREAM_REVISION_OR_VERSION`: `2fd153c67988e980fb0b2455c90832159a6a5a25`
- `INSTALL_METHOD`: copied the official `skills/caveman/SKILL.md` and its README into this repository from the pinned source revision after confirming the supported Skills CLI path would invoke global setup. No global proxy was installed.
- `PROJECT_FILES_CREATED`: `.agents/skills/caveman/`
- `PROJECT_FILES_MODIFIED`: `skills-lock.json` contains project-local skills metadata.
- `GLOBAL_STATE_MODIFIED`: `NO`
- `CAVEMAN_GLOBAL_PROXY_INSTALLED`: `NO`

### LSP-AI

- `UPSTREAM_SOURCE`: [SilasMarvin/lsp-ai](https://github.com/SilasMarvin/lsp-ai)
- `UPSTREAM_REVISION_OR_VERSION`: repository `1e910a8cf0048406eb227bf2064743010a9ff3a9`; release `v0.7.1`
- `INSTALL_METHOD`: project-local official Windows x64 release under ignored `.tools/lsp-ai/`. Upstream published no checksum asset; the installer pins the reviewed HTTPS archive SHA-256 `d52a7441025e86f8d18289655ea49207f7d312013757a93df80141ba7012478b`. This is a local reproducibility pin, not an upstream signature.
- `PROJECT_FILES_CREATED`: `.codex/lsp-ai-initialization.json`; executable in ignored `.tools/lsp-ai/`.
- `PROJECT_FILES_MODIFIED`: `.gitignore`, `scripts/tooling/install-agent-tools.ps1`
- `GLOBAL_STATE_MODIFIED`: `NO`
- `LSP_AI_PROVIDER_CONFIGURED`: `NO`

LSP-AI is an optional editor language server, not a skill or Codex MCP. The local binary and initialization options were verified without model completion or external provider credentials. No editor client configuration is committed because no editor was selected. A developer choosing to use it must configure their editor; keep that setup project-scoped where the editor supports it. Upstream states that new feature development is not currently active, so this is optional and should not block product work.

## Skill Routing Policy

Use one primary workflow for the task phase. Add a supporting skill only when it covers a distinct need; do not load all skills, repeat equivalent planning, or run duplicate reviews.

| Situation                            | Primary tool/skill                   | Secondary                                                                                  | Must not replace                                            |
| ------------------------------------ | ------------------------------------ | ------------------------------------------------------------------------------------------ | ----------------------------------------------------------- |
| Ambiguous domain/product change      | Matt `grill-with-docs`               | Addy `interview-me` only if it resolves a specific interview need; currently not installed | Planning contract and architecture docs                     |
| Focused requirement question         | Matt `grill-me`                      | None                                                                                       | Issue acceptance criteria                                   |
| Turn agreed requirements into a spec | Matt `to-spec`                       | Addy's planning workflow only if a distinct planning gap exists                            | Focused GitHub issue                                        |
| Implement approved scope             | Matt `implement`                     | Addy `/build` workflow concept if needed                                                   | Issue scope and validation                                  |
| Clear behavioral seam                | Matt `tdd`                           | Addy test guidance if useful                                                               | Acceptance criteria                                         |
| Bug diagnosis                        | Matt `diagnosing-bugs`               | CodeDB or Lexa as appropriate                                                              | Reproduction and regression test                            |
| API boundary design                  | Addy `api-and-interface-design`      | Matt `tdd` during implementation                                                           | Architecture documents                                      |
| Frontend feature                     | Addy `frontend-ui-engineering`       | Accessibility reference                                                                    | Astro-first and no-`useEffect` rules                        |
| Security-sensitive change            | Addy `security-and-hardening`        | RLS/security architecture                                                                  | Authorization tests                                         |
| Performance work                     | Addy `performance-optimization`      | CodeDB for focused context                                                                 | Measurement                                                 |
| Review                               | Addy `code-review-and-quality`       | anti-slop findings                                                                         | Human review and CI                                         |
| Ship/release preparation             | Addy `shipping-and-launch`           | None                                                                                       | Human approval; no auto-merge                               |
| Periodic architecture review         | Matt `improve-codebase-architecture` | Lexa impact/audit if useful                                                                | Approved architecture decisions                             |
| Token-heavy low-value explanation    | Caveman                              | Compact context queries                                                                    | Exact code, commands, errors, risks, or validation evidence |

Do not invoke `grill-me` for every small edit. Ask only questions that materially reduce scope ambiguity.

## CodeDB and Lexa Selection

- Use **CodeDB first** for focused repository context: where something lives, symbol definitions, callers, outlines, and local call paths. Its Codex MCP starts lazily and is configured to keep its cache and project index in `.tools/`.
- Use **Lexa** when graph-based dependency impact, reverse dependencies, audit candidates, or hash-aware reads provide distinct value. Refresh its local index once after meaningful source changes; do not run both indexers for the same question.
- Neither tool changes code or decides correctness. Verify findings with source, tests, lint, typecheck, and build. Audit findings are candidates for investigation, not automatic defects.
- Project MCP IDs are `codedb_elearning` and `lexa_elearning`; both are registered only in `.codex/config.toml`. `codex mcp list` from this checkout showed them; from a directory outside the repository they were absent. No credentials are stored in the config.

## Token-Efficiency Policy

Use Caveman selectively for repetitive status narration and low-value prose. Keep exact source, code, shell commands, security warnings, acceptance criteria, errors, failure output, unresolved decisions, and validation evidence intact. Compression must not obscure a failure or remove the original recoverable output where the upstream tool supports that distinction. The global Caveman proxy is intentionally not installed.

## Lint Policy

`pnpm lint` runs the existing ESLint and Turbo lint tasks plus `pnpm lint:anti-slop` (`oxlint apps packages scripts`). The normal CI `lint` step therefore runs anti-slop without AI credentials or binary downloads. `pnpm check:constraints` remains a separate existing architecture guard; neither gate replaces TypeScript or tests. Keep customized rules documented and pin Oxlint/plugin versions together.

See the official [Oxlint configuration](https://oxc.rs/docs/guide/usage/linter/config) and [JavaScript plugin](https://oxc.rs/docs/guide/usage/linter/js-plugins) docs. JavaScript plugin support is Alpha.

## Codex Discovery and Installation

The configuration follows [Codex MCP docs](https://developers.openai.com/codex/mcp/) and the [configuration reference](https://developers.openai.com/codex/config-reference/) for project-scoped configuration and trust behavior.

Codex project MCP configuration is in `.codex/config.toml` and loads when this trusted repository is the working project. The configuration uses project-local PowerShell launchers; binaries, indexes, and caches are not committed. Skill files under `.agents/skills/` are project-local and discoverable by Codex/Skills CLI. Set a process-local npm cache before Skills CLI commands, then check `npx skills@1.7.0 list --agent codex` from the project:

```powershell
$env:npm_config_cache = Join-Path (Get-Location) '.tools/npm-cache'
npx skills@1.7.0 list --agent codex
```

Do not add `--global`/`-g`, edit a user Codex config, or install global npm packages.

On Windows, install pinned local tools with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/tooling/install-agent-tools.ps1
```

The script confines downloads and extracted binaries to `.tools/` and verifies upstream CodeDB/Lexa checksums. LSP-AI's local archive hash is pinned but not upstream-attested. Use the project MCP entries by default. A direct CodeDB CLI invocation must first set process-local `USERPROFILE` to `.tools/codedb/profile`, or CodeDB would store its index under the user's home directory; Lexa CLI invocations must pass `--graph .tools/lexa/index.sqlite`. Never add local binaries/indexes/caches to Git. Skills are source-controlled because project-wide agent instructions are intended to be shared.

## Verification Procedure

After changing tool versions/configuration:

1. Run `pnpm install --frozen-lockfile`, `pnpm check:constraints`, `pnpm lint`, `pnpm typecheck`, `pnpm test`, `pnpm build`, `pnpm format:check`, and `git diff --check`.
2. Verify project skill scope and load one representative skill from Matt and Addy; use one brief Caveman smoke test only when its behavior changes.
3. Run `codex mcp list` in this repository and verify local CodeDB/Lexa MCP handshakes and real context/graph queries. Verify they do not appear from outside this repository.
4. For CodeDB, check local project status, context, and one known symbol. For Lexa, check `brief`, symbol search, outline, dependency trace, and audit.
5. Verify LSP-AI binary version and a local LSP initialization handshake. Do not configure a provider or invoke a model as a tooling smoke test.
6. Scan staged files for secrets and ensure `.tools/`, local indexes, logs, and caches remain ignored.

Tests, compiler checks, lint, and CI remain authoritative. No tool smoke test substitutes for them.

## Known Limitations and Update Procedure

- The full `pnpm format:check` currently reports 55 pre-existing Foundation files that are unchanged on this branch. All supported changed documentation and configuration files pass a targeted Prettier check. The current GitHub CI does not run `format:check`; changing unrelated Foundation formatting is deferred to a separate cleanup.
- Skills CLI and upstream repositories move independently; this project pins source commits in this inventory and installed metadata. Review upstream docs and diffs before updating skills, copied references, or vendored rules.
- Lexa is archived; treat security/maintenance updates as an explicit review, not unattended latest installation.
- CodeDB lazy MCP is documented upstream as experimental. If it breaks, fall back to the local CLI or disable only the MCP registration; do not change global Codex configuration.
- Oxlint JavaScript plugins are alpha. Keep matching pinned versions, run the full project gate, and review rule behavior before accepting upgrades.
- LSP-AI is optional and editor-specific. Its local binary/initialization handshake does not prove integration with any particular editor or AI provider.
- `show-me` is not native to Matt Pocock's pinned skill collection and remains uninstalled.

To update: inspect the upstream repository and installation docs, select a specific commit/release, update project-local skills or the pinned installer, update this inventory and any rule provenance, verify local-only boundaries, run all project checks and the relevant tool smoke tests, then submit through the usual issue/branch/PR/human-review workflow. Do not mutate machine-wide configuration as part of an update.
