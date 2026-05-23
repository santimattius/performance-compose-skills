# Installation — multi-agent

These skills follow the [Agent Skills](https://agentskills.io) spec (`SKILL.md` + `references/`). They work across **Claude Code**, **Cursor**, **Gemini CLI**, **Antigravity**, **OpenCode**, and **Codex**.

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

| Skill | Use when |
|-------|----------|
| `compose-composition-core` | State, recomposition, stability |
| `compose-modifier-system` | Modifiers, layout/draw phase |
| `compose-effects` | Side effects, `snapshotFlow` |
| `compose-animations` | Animations, `graphicsLayer` |
| `compose-architecture` | Clean Arch, MVVM, UiState |
| `compose-navigation-nav3` | Navigation 3, NavKey |
| `compose-previews-tooling` | Previews, Baseline Profiles |
| `compose-quality` | A11y, semantics, UI tests |

Full registry: [AGENTS.md](../AGENTS.md)

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
