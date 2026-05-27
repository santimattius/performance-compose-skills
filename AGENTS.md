# AGENTS.md — Skill Registry

> **Performance Note**: Every skill in this registry leads with the Compose 3-phase performance model (Composition → Layout → Drawing). Load the relevant skill BEFORE writing Compose code — phase-awareness is non-negotiable.

> **Install**: Skills live under `skills/` in this repo. Install into Claude Code, Cursor, Gemini CLI, Antigravity, OpenCode, or Codex via `npx skills add santimattius/performance-compose-skills --skill '*' -a <agent> -y` — see [docs/INSTALL.md](docs/INSTALL.md).

> **CMP**: Every skill carries a `## CMP Applicability` table. Canonical CMP rules live in [`skills/_shared/cmp-platform.md`](skills/_shared/cmp-platform.md) — source-set map, forbidden imports, lifecycle version gates, navigation options, tooling matrix.

## Jetpack Compose

<!-- Tier 1: Foundations -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-composition-core` | State, recomposition, stability, CompositionLocal, `retain`, `derivedStateOf`, backwards-write, `commonMain` remember platform leaks, `CMP-REMEMBER-PLATFORM-LEAK` | [SKILL.md](skills/compose-composition-core/SKILL.md) |
| `compose-modifier-system` | Custom modifiers, `ModifierNodeElement`, layout/draw phase work, `graphicsLayer`, drawing APIs, KMP modifier patterns | [SKILL.md](skills/compose-modifier-system/SKILL.md) |

<!-- Tier 2: Runtime -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-effects` | `LaunchedEffect`, `DisposableEffect`, `SideEffect`, `snapshotFlow`, `rememberUpdatedState`, `derivedStateOf` in scroll, `collectAsStateWithLifecycle` CMP version gate | [SKILL.md](skills/compose-effects/SKILL.md) |
| `compose-animations` | `animate*AsState`, `updateTransition`, `Animatable`, `graphicsLayer` lambda, `AnimatedVisibility`, `animateContentSize`, CMP animations in `commonMain` | [SKILL.md](skills/compose-animations/SKILL.md) |

<!-- Tier 3: App-level -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-architecture` | Clean Arch + MVI/MVVM in Compose, `collectAsStateWithLifecycle`, UiState/UiAction, Screen/Content split, CMP `expect`/`actual` ViewModel/DI boundary, Koin vs Hilt in `commonMain` | [SKILL.md](skills/compose-architecture/SKILL.md) |
| `compose-views-interop` | View↔Compose interop (Android-only) during incremental migration: `ComposeView`, `AndroidView`, `ViewCompositionStrategy`, RecyclerView/ViewPager2, Fragment/Dialog hybrids, custom View wrappers; CMP interop pointer (`UIKitView`/`SwingPanel`) | [SKILL.md](skills/compose-views-interop/SKILL.md) |
| `compose-navigation-nav3` | Nav3 1.0.0 (Android stable), `NavKey`, `NavDisplay`, `NavBackStack`, `SceneStrategy`, ViewModel decorators, Nav2 migration; CMP Nav3 (`org.jetbrains.androidx.navigation3` 1.0.0-alpha05, CMP 1.10+); CMP navigation alternatives (compose-router, Decompose, Voyager); `desktopMain`/`iosMain`/`wasmJsMain` navigation | [SKILL.md](skills/compose-navigation-nav3/SKILL.md) |

<!-- Tier 4: Cross-cutting -->
| Skill | Trigger | Link |
|-------|---------|------|
| `compose-previews-tooling` | `@Preview`, `@PreviewWrapper` (April 2026), `@PreviewParameter`, screenshot testing, Baseline Profiles, Compiler Reports, Composition Tracing, Macrobenchmark (Android-only); JetBrains `@Preview` + Compose Hot Reload (CMP); `runComposeUiTest` in `commonTest` | [SKILL.md](skills/compose-previews-tooling/SKILL.md) |
| `compose-quality` | Accessibility semantics, `mergeDescendants`, `customActions`, `liveRegion`, `traversalIndex`, UI tests, Paparazzi, Roborazzi; CMP iOS VoiceOver + `AccessibilitySyncOptions`; `runComposeUiTest` multiplatform; `iosMain` a11y with `performAccessibilityAudit()` | [SKILL.md](skills/compose-quality/SKILL.md) |

<!-- Audit & Triage -->
## Audit & Triage

| Skill | Trigger | Link |
|-------|---------|------|
| `compose-audit` | Audit a Compose / CMP project; classify findings (critical/warning/suggestion) and route to canonical skills. Triggers: "audit my Compose project", "review CMP code", "find perf issues in Compose", "recomposition audit", `commonMain` platform API violations, `CMP-*` patterns | [SKILL.md](skills/compose-audit/SKILL.md) |
