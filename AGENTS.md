# AGENTS.md — Skill Registry

> **Performance Note**: Every skill in this registry leads with the Compose 3-phase performance model (Composition → Layout → Drawing). Load the relevant skill BEFORE writing Compose code — phase-awareness is non-negotiable.

> **Install**: Skills live under `skills/` in this repo. Install into Claude Code, Cursor, Gemini CLI, Antigravity, OpenCode, or Codex via `npx skills add santimattius/performance-compose-skills --skill '*' -a <agent> -y` — see [docs/INSTALL.md](docs/INSTALL.md).

## Jetpack Compose

<!-- Tier 1: Foundations -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-composition-core` | State, recomposition, stability, CompositionLocal, `retain`, `derivedStateOf`, backwards-write | [SKILL.md](skills/compose-composition-core/SKILL.md) |
| `compose-modifier-system` | Custom modifiers, `ModifierNodeElement`, layout/draw phase work, `graphicsLayer`, drawing APIs | [SKILL.md](skills/compose-modifier-system/SKILL.md) |

<!-- Tier 2: Runtime -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-effects` | `LaunchedEffect`, `DisposableEffect`, `SideEffect`, `snapshotFlow`, `rememberUpdatedState`, `derivedStateOf` in scroll | [SKILL.md](skills/compose-effects/SKILL.md) |
| `compose-animations` | `animate*AsState`, `updateTransition`, `Animatable`, `graphicsLayer` lambda, `AnimatedVisibility`, `animateContentSize` | [SKILL.md](skills/compose-animations/SKILL.md) |

<!-- Tier 3: App-level -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-architecture` | Clean Arch + MVI/MVVM in Compose, `collectAsStateWithLifecycle`, UiState/UiAction, Screen/Content split | [SKILL.md](skills/compose-architecture/SKILL.md) |
| `compose-navigation-nav3` | Nav3 1.0.0, `NavKey`, `NavDisplay`, `NavBackStack`, `SceneStrategy`, ViewModel decorators, Nav2 migration | [SKILL.md](skills/compose-navigation-nav3/SKILL.md) |

<!-- Tier 4: Cross-cutting -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-previews-tooling` | `@Preview`, `@PreviewWrapper` (April 2026), `@PreviewParameter`, screenshot testing, Baseline Profiles, Compiler Reports, Composition Tracing, Macrobenchmark | [SKILL.md](skills/compose-previews-tooling/SKILL.md) |
| `compose-quality` | Accessibility semantics, `mergeDescendants`, `customActions`, `liveRegion`, `traversalIndex`, UI tests, Paparazzi, Roborazzi | [SKILL.md](skills/compose-quality/SKILL.md) |

<!-- Audit & Triage -->
## Audit & Triage

| Skill | Trigger | Link |
|-------|---------|------|
| `compose-audit` | Audit a Compose / CMP project; classify findings (critical/warning/suggestion) and route to canonical skills. Triggers: "audit my Compose project", "review CMP code", "find perf issues in Compose", "recomposition audit" | [SKILL.md](skills/compose-audit/SKILL.md) |
