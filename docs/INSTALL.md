# Installation — multi-agent

These skills follow the [Agent Skills](https://agentskills.io) spec (`SKILL.md` + `references/`). They work across **Claude Code**, **Cursor**, **Gemini CLI**, **Antigravity**, **OpenCode**, and **Codex**.

They target **Jetpack Compose** and **Compose Multiplatform**. Most skills teach fixes; **[compose-audit](../skills/compose-audit/SKILL.md)** audits a codebase and routes each finding to the right skill.

## Recommended: install all agents at once

Uses the [skills CLI](https://github.com/vercel-labs/skills) (`npx skills`). It detects your repo layout (`skills/`) and installs each skill into the correct directory per agent.

```bash
# From your Android project (workspace install — commit .agents/skills with your team)
npx skills add santimattius/performance-compose-skills \
  --skill '*' \
  -a claude-code \
  -a cursor \
  -a gemini-cli \
  -a antigravity \
  -a opencode \
  -a codex \
  -y

# Global install (available in every project on this machine)
npx skills add santimattius/performance-compose-skills \
  --skill '*' \
  -g \
  -a claude-code \
  -a cursor \
  -a gemini-cli \
  -a antigravity \
  -a opencode \
  -a codex \
  -y
```

List skills in this repo without installing:

```bash
npx skills add santimattius/performance-compose-skills --list
```

Local clone (development):

```bash
npx skills add /path/to/performance-compose-skills --skill '*' -a cursor -y
```

Convenience script from this repository:

```bash
./scripts/install-skills.sh          # workspace
./scripts/install-skills.sh --global # user-wide
```

### Audit skill only

Install just the audit/triage skill (includes `assets/` report template and routing table):

```bash
npx skills add santimattius/performance-compose-skills \
  --skill compose-audit \
  -a cursor -y
```

Useful triggers: *"audit my Compose project"*, *"review CMP code"*, *"find perf issues in Compose"*. For fixes after the audit, install the routed skills (or use `--skill '*'`).

### Where files land

| Agent | `--agent` | Project path | Global path |
|-------|-----------|--------------|-------------|
| Claude Code | `claude-code` | `.claude/skills/` | `~/.claude/skills/` |
| Cursor | `cursor` | `.agents/skills/` | `~/.cursor/skills/` |
| Gemini CLI | `gemini-cli` | `.agents/skills/` | `~/.gemini/skills/` |
| Antigravity | `antigravity` | `.agents/skills/` | `~/.gemini/antigravity/skills/` |
| OpenCode | `opencode` | `.agents/skills/` | `~/.config/opencode/skills/` |
| Codex | `codex` | `.agents/skills/` | `~/.codex/skills/` |

> **Cursor note:** Cursor also reads `.cursor/skills/` natively. The skills CLI installs to `.agents/skills/` (shared Agent Skills layout). Both work; prefer `npx skills` for consistency across agents.

> **OpenCode note:** OpenCode also discovers `.opencode/skills/`, `.claude/skills/`, and `.agents/skills/` when walking up from your cwd.

---

## Shared resources

Every skill links to `skills/_shared/cmp-platform.md` for canonical CMP platform rules (source-set map, lifecycle version gates, navigation options, tooling matrix). The `_shared/` directory is **not a skill** and is NOT automatically installed by `npx skills add --skill '*'` — it is not recognized as a skill because it has no root `SKILL.md`.

### Option A — Full install (recommended): use `--skill '*'`

When installing all skills, copy `_shared/` manually after `npx skills` completes:

```bash
# After npx skills add ...
# Cursor project install:
cp -R skills/_shared .agents/skills/_shared

# Claude Code project install:
cp -R skills/_shared .claude/skills/_shared

# Global Cursor:
cp -R skills/_shared ~/.cursor/skills/_shared

# Global Claude Code:
cp -R skills/_shared ~/.claude/skills/_shared
```

### Option B — Single-skill install

If you install a single skill (e.g. `--skill compose-effects`), the `## CMP Applicability` link to `_shared/cmp-platform.md` may not resolve locally. In that case either:

1. Copy `_shared/` alongside the installed skill (same as Option A), or
2. Load `_shared/cmp-platform.md` directly from GitHub raw URL:
   `https://raw.githubusercontent.com/santimattius/performance-compose-skills/main/skills/_shared/cmp-platform.md`

---

## Per-agent (native commands)

### Claude Code (plugin marketplace)

Best for `/plugin install` and versioned marketplace updates:

```bash
/plugin marketplace add santimattius/performance-compose-skills
/plugin install performance-compose-skills@performance-compose-skills
```

Local:

```bash
/plugin marketplace add /path/to/performance-compose-skills
/plugin install performance-compose-skills@performance-compose-skills
```

Manifest: [.claude-plugin/plugin.json](../.claude-plugin/plugin.json) · [.claude-plugin/marketplace.json](../.claude-plugin/marketplace.json)

### Cursor

**Option A — skills CLI (recommended)**

```bash
npx skills add santimattius/performance-compose-skills --skill '*' -a cursor -y
```

**Option B — manual (Cursor-native path)**

```bash
git clone https://github.com/santimattius/performance-compose-skills.git
mkdir -p .cursor/skills
cp -R performance-compose-skills/skills/* .cursor/skills/
# or symlink:
ln -s "$(pwd)/performance-compose-skills/skills" .cursor/skills/compose-performance
```

Point your project rules at [AGENTS.md](../AGENTS.md) or load skills by trigger from each `SKILL.md` frontmatter.

### Gemini CLI

**Option A — skills CLI**

```bash
npx skills add santimattius/performance-compose-skills --skill '*' -a gemini-cli -y
```

**Option B — gemini skills**

```bash
gemini skills install https://github.com/santimattius/performance-compose-skills.git --scope workspace
# or global:
gemini skills install https://github.com/santimattius/performance-compose-skills.git --scope user
```

Discovery paths: `.gemini/skills/`, `.agents/skills/`, `~/.gemini/skills/`.

### Antigravity

**Option A — skills CLI**

```bash
npx skills add santimattius/performance-compose-skills --skill '*' -a antigravity -y
```

**Option B — manual**

```bash
mkdir -p .agents/skills
cp -R /path/to/performance-compose-skills/skills/* .agents/skills/
```

Workspace: `.agents/skills/` · Global: `~/.gemini/antigravity/skills/`

### OpenCode

**Option A — skills CLI**

```bash
npx skills add santimattius/performance-compose-skills --skill '*' -a opencode -y
```

**Option B — manual**

```bash
mkdir -p .agents/skills
cp -R /path/to/performance-compose-skills/skills/* .agents/skills/
```

OpenCode also reads `.opencode/skills/` and `.claude/skills/` (project and global).

### Codex

**Option A — skills CLI**

```bash
npx skills add santimattius/performance-compose-skills --skill '*' -a codex -y
```

**Option B — manual**

```bash
mkdir -p .agents/skills
cp -R /path/to/performance-compose-skills/skills/* .agents/skills/
```

Codex scans `.agents/skills/` from cwd up to the git root. User skills: `~/.codex/skills/`.

**Registry in instructions:** Copy or link [AGENTS.md](../AGENTS.md) to your repo root so Codex loads the skill index and performance-first rule:

```bash
curl -o AGENTS.md https://raw.githubusercontent.com/santimattius/performance-compose-skills/main/AGENTS.md
```

Invoke a skill explicitly with `$skill-name` or `/skills` in the Codex UI.

---

## Skills included

| Tier | Skill | Use when |
|------|-------|----------|
| 1 | `compose-composition-core` | State, recomposition, stability |
| 1 | `compose-modifier-system` | Modifiers, layout/draw phase |
| 2 | `compose-effects` | Side effects, `snapshotFlow` |
| 2 | `compose-animations` | Animations, `graphicsLayer` |
| 3 | `compose-architecture` | Clean Arch, MVVM, UiState |
| 3 | `compose-navigation-nav3` | Navigation 3, NavKey |
| 4 | `compose-previews-tooling` | Previews, Baseline Profiles |
| 4 | `compose-quality` | A11y, semantics, UI tests |
| Audit | `compose-audit` | Audit Compose/CMP; severity + route to fix skills |

`compose-audit` layout: `SKILL.md`, `references/`, and `assets/` (`AUDIT-REPORT.md`, `routing-table.md`).

Full registry (4 tiers + Audit & Triage): [AGENTS.md](../AGENTS.md)

---

## Update / remove

```bash
npx skills update compose-composition-core   # example
npx skills list -a cursor
npx skills remove compose-composition-core -a cursor -y
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Agent does not see skills | Reopen session; run `npx skills list -a <agent>` and confirm paths |
| Wrong skill version | `npx skills update -y` or reinstall from GitHub |
| Claude marketplace vs skills CLI | Marketplace → `.claude-plugin`; `npx skills` → `.claude/skills/` or `.agents/skills/` — both are valid |
| Monorepo / partial install | `npx skills add ... --skill compose-composition-core --skill compose-effects` |
| Audit without full bundle | `npx skills add ... --skill compose-audit -a cursor -y` then add routed skills as needed |
