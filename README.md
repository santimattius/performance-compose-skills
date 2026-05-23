# performance-compose-skills

Performance-first AI agent skills for **Jetpack Compose**. Each skill leads with the 3-phase model (Composition → Layout → Drawing) and includes decision trees, critical patterns, and a shared performance toolchain.

**Author:** Santiago Mattiauda  
**License:** Apache-2.0

## Skills

| Tier | Skill | Focus |
|------|-------|--------|
| 1 | [compose-composition-core](skills/compose-composition-core/SKILL.md) | State, recomposition, stability, identity |
| 1 | [compose-modifier-system](skills/compose-modifier-system/SKILL.md) | Modifiers, layout/draw phase, `ModifierNodeElement` |
| 2 | [compose-effects](skills/compose-effects/SKILL.md) | Side effects, `snapshotFlow`, effect keys |
| 2 | [compose-animations](skills/compose-animations/SKILL.md) | Animations in Drawing phase, `graphicsLayer` |
| 3 | [compose-architecture](skills/compose-architecture/SKILL.md) | Clean Architecture, MVVM, UiState |
| 3 | [compose-navigation-nav3](skills/compose-navigation-nav3/SKILL.md) | Navigation 3, NavKey, decorators |
| 4 | [compose-previews-tooling](skills/compose-previews-tooling/SKILL.md) | Previews, Baseline Profiles, profiling |
| 4 | [compose-quality](skills/compose-quality/SKILL.md) | Accessibility, semantics, UI testing |

Full registry: [AGENTS.md](AGENTS.md)

## Installation

Supported agents: **Claude Code**, **Cursor**, **Gemini CLI**, **Antigravity**, **OpenCode**, and **Codex**.

### Quick install (all agents)

```bash
npx skills add santimattius/performance-compose-skills \
  --skill '*' \
  -a claude-code -a cursor -a gemini-cli -a antigravity -a opencode -a codex \
  -y
```

Or from a local clone:

```bash
./scripts/install-skills.sh --local
```

Full paths, native commands, and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**

### Claude Code (marketplace)

```bash
/plugin marketplace add santimattius/performance-compose-skills
/plugin install performance-compose-skills@performance-compose-skills
```

### Project registry

Add [AGENTS.md](AGENTS.md) to your Android repo (or symlink it) so agents load the skill index and the Composition → Layout → Drawing rule before writing Compose code.

Each skill is self-contained: `SKILL.md` + `references/` (no external doc dependencies).

## Structure

```
skills/                    # Agent Skills (SKILL.md per skill)
├── compose-composition-core/
│   ├── SKILL.md
│   └── references/
├── ...
.claude-plugin/           # Claude Code plugin + marketplace
├── plugin.json
└── marketplace.json
docs/INSTALL.md            # Multi-agent install guide
scripts/install-skills.sh  # Install into all supported agents
AGENTS.md                  # Skill registry (4 tiers)
```

## Contributing

Skills follow the [Agent Skills](https://agentskills.io) convention. Pull requests welcome for corrections and Compose API updates — include validation date in the skill's Validation footer.
