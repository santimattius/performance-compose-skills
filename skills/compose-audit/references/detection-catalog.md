# Detection Catalog

Canonical routing: [assets/routing-table.md](../assets/routing-table.md).

For each hit, build a `raw_signal` (`pattern_id`, `file`, `line`, `snippet`, `source_set`). Read surrounding code before promoting to a finding.

## Composition — compose-composition-core

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| COR-COMPOSITION-WRITE | `rg -n 'by remember.*MutableState' -t kotlin` then manual: assignment in `@Composable` body | Backwards-write |
| COR-UNSTABLE-PARAM | Compiler `*-classes.txt` unstable lines; or `rg -n '@Composable' -A 5` + param types with `List`/`Map`/`Mutable` | Cross-check reports |
| COR-LAZY-NO-KEY | `rg -n 'items\s*\([^)]+\)\s*\{' -t kotlin` without `key\s*=` on same line/block | LazyColumn/Grid |
| COR-DERIVED-EQUAL | `rg -n 'derivedStateOf' -t kotlin -A 3` | Output same as input |
| COR-STATIC-LOCAL-VARYING | `rg -n 'staticCompositionLocalOf' -t kotlin -A 5` | Runtime-varying provider |

## Modifiers — compose-modifier-system

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| MOD-ORDER | `rg -n 'Modifier\..*padding.*\.(size|width|height)' -t kotlin` | Heuristic; confirm intent |
| MOD-DRAW-IN-COMPOSITION | Manual: expensive work before `drawLine`/`drawPath` outside lambda | Prefer `drawBehind { }` |
| MOD-NEW-MODIFIER-PER-RECOMP | `rg -nU 'items[^{]*\{[^}]*Modifier\.' -t kotlin` | Hoist modifier when stable |

## Effects — compose-effects

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| EFF-LAUNCHED-EFFECT-UNIT | `rg -n 'LaunchedEffect\s*\(\s*Unit\s*\)' -t kotlin -A 5` | Body uses outer vars? |
| EFF-GLOBAL-SCOPE | `rg -n 'GlobalScope\.|CoroutineScope\s*\(\s*Job\s*\(\s*\)\s*\)' -t kotlin` | Inside `@Composable` or effects |
| EFF-DISPOSABLE-EMPTY-DISPOSE | `rg -nU 'DisposableEffect[\s\S]{0,200}onDispose\s*\{\s*\}' -t kotlin` | Missing cleanup |
| EFF-COLLECT-NOT-LIFECYCLE | `rg -n '\.collectAsState\s*\(' -t kotlin` in `androidMain`/`main` | Not Screen+VM case |
| EFF-RUNBLOCKING-IN-COMPOSE | `rg -n 'runBlocking\s*\{' -t kotlin` near `@Composable`/`LaunchedEffect` | ANR risk |

## Animations — compose-animations

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| ANI-STATE-IN-COMPOSITION | `rg -n 'Animatable.*\.value' -t kotlin` in `@Composable` body | Defer to graphicsLayer |
| ANI-ANIMATE-CONTENT-SIZE-MISUSE | Manual: `animateContentSize` + rapidly changing children | |
| ANI-INFINITE-TRANSITION-LEAK | `rg -n 'rememberInfiniteTransition' -t kotlin -A 8` | Off-screen without disposal |

## Architecture — compose-architecture

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| ARCH-STATE-FLOW-NO-LIFECYCLE | `viewModel(` / `hiltViewModel` in same file as `collectAsState()` without `WithLifecycle` | Apply disambiguator |
| ARCH-SCREEN-CONTENT-MIXED | `rg -n 'hiltViewModel|viewModel\s*\(' -t kotlin -B 2 -A 40` | VM + large UI in one composable |
| ARCH-MUTATING-UI-STATE-IN-COMPOSITION | Manual: `uiState = uiState.copy` in composable body | Event/callback only |

## Navigation — compose-navigation-nav3

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| NAV-NAV2-LEFTOVER | `rg -n 'androidx\.navigation\.compose\.NavHost' -t kotlin` | Migration candidate |
| NAV-NAV3-NO-DECORATOR | `rg -n 'NavDisplay\s*\(' -t kotlin -A 8` | Missing lifecycle decorator |
| NAV-NAVKEY-NOT-PARCELABLE | `rg -n ': NavKey' -t kotlin -B 3` | Missing `@Parcelize` |

## Previews & tooling — compose-previews-tooling

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| PRV-NO-PREVIEW-PARAM | `rg -l '@Composable' -t kotlin path/to/ui` vs `rg -l '@Preview'` | Public composables in ui package |
| PRV-NO-COMPILER-REPORTS | From discovery — no `reportsDestination` | Project-level |
| PRV-NO-BASELINE-PROFILE | `rg -n 'baselineprofile' settings.gradle*` | Release Android apps |

## Quality — compose-quality

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| QLT-NO-SEMANTICS | `rg -n '\.clickable' -t kotlin` without nearby `semantics`/`contentDescription` | Filter images with desc |
| QLT-MERGE-DESCENDANTS-MISSING | Manual: custom clickable Row/Column | Button-like components |
| QLT-LIVE-REGION-MISSING | Manual: loading/error `Text` without `liveRegion` | |

## Interop — compose-views-interop

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| INTEROP-ANDROIDVIEW-UPDATE-HEAVY | `rg -nU 'AndroidView\s*\([^)]*update\s*=' -t kotlin -A 15` | Allocations, `setText`, full rebuild in update |
| INTEROP-COMPOSEVIEW-WRONG-STRATEGY | `rg -n 'ComposeView' -t kotlin -B 2 -A 12` without `setViewCompositionStrategy` in Fragment/Dialog file | Default strategy in Fragment |
| INTEROP-RECYCLERVIEW-RESET-CONTENT | `rg -n 'onBindViewHolder' -t kotlin -A 20` with `setContent` | setContent per bind |
| INTEROP-VIEWPAGER2-OFFSCREEN-COMPOSE | `rg -n 'offscreenPageLimit\s*=\s*[3-9]' -t kotlin` near Compose/Fragment pages | High limit + heavy Compose pages |
| INTEROP-DIALOG-NO-LIFECYCLE-OWNER | `rg -n 'DialogFragment|BottomSheetDialog' -t kotlin -A 25` + `ComposeView` without `DisposeOnViewTreeLifecycleDestroyed` | Dialog window lifecycle |
| INTEROP-ANDROIDVIEW-UNNECESSARY | `rg -n 'AndroidView\s*\(' -t kotlin -A 8` wrapping Text/Button-like custom UI | Confirm no SDK requirement |

## CMP — compose-architecture / compose-composition-core

| pattern_id | Ripgrep / review | Notes |
|---|---|---|
| CMP-PLATFORM-API-IN-COMMON | `rg -n '^import (android\.|platform\.UIKit|java\.awt\.)' --glob '**/commonMain/**'` | critical |
| CMP-EXPECT-NO-ACTUAL | `rg -n '^expect ' --glob '**/commonMain/**'` + cross-target `actual` | |
| CMP-REMEMBER-PLATFORM-LEAK | `rg -n 'remember\s*\{' --glob '**/commonMain/**' -A 2` | Platform types |

## Docs validation (after classification)

| pattern prefix | Tool |
|----------------|------|
| `CMP-*` | context7: Compose Multiplatform / kotlinlang docs |
| Android API claims | `android docs search '<concept>'` |
| Internal heuristic only | `evidence_docs: (internal heuristic)` |
