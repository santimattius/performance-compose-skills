---
name: compose-views-interop
description: >
  (Android-only — uses android.view.View)
  Performance-first View↔Compose interoperability during incremental migration:
  ComposeView, AndroidView, ViewCompositionStrategy, RecyclerView/ViewPager2 hybrids,
  Dialog/BottomSheet, Fragment and multi-Activity hosting. Trigger: AndroidView,
  ComposeView, View interop, custom View in Compose, RecyclerView Compose, hybrid screen,
  migration coexistence, ViewCompositionStrategy.
license: Apache-2.0
metadata:
  author: Santiago Mattiauda
  version: "1.0"
---

## Performance First

Every Compose frame runs three phases. Cost rises left-to-right; restart scope shrinks left-to-right.

| Phase | What Runs | Restart Cost | Trigger |
|-------|-----------|--------------|---------|
| Composition | Composable functions, state reads | HIGH (whole scope) | State read in composable body |
| Layout | Measure + place | MEDIUM (subtree) | State read in measure lambda |
| Drawing | Canvas commands, graphicsLayer | LOW (single node) | State read in draw/graphicsLayer lambda |

### Interop boundary costs

| Boundary | Extra cost | Phase impact |
|----------|------------|--------------|
| `AndroidView` | Real `View` measure/layout/draw per frame | **`update` runs in Composition** — any `State` read there retriggers subtree |
| `ComposeView` | Separate composition owner + View attach | Wrong `ViewCompositionStrategy` → leaked compositions or state loss on detach |
| Hybrid scroll | Two input systems | Layout + jank if nested scroll not coordinated |
| Mixed APK | Build/size (not runtime by default) | See [references/interop-performance-checklist.md](references/interop-performance-checklist.md) |

**Rule**: at interop boundaries, minimize Composition-phase work; prefer stable parameters and lifecycle-correct disposal.

---

## Performance Toolchain

> WARNING: NEVER profile in debug builds. Debug disables R8, inlining, and Strong Skipping — numbers are meaningless. Always profile a **release** build with `profileable` enabled or a benchmark build type.

| Tool | Use For | When |
|------|---------|------|
| Layout Inspector (recomposition counts) | Hot `AndroidView` / parent recomposing on scroll | Hybrid screens flagged in audit |
| Composition Tracing | Frame spikes at interop nodes | When Layout Inspector shows boundary churn |
| Macrobenchmark | Scroll/startup on hybrid screens | Per-release regression on RecyclerView/ViewPager2 hosts |
| Baseline Profiles | AOT paths outside Compose library profile | App-specific View-heavy startup |
| `android docs search` | Validate interop API claims | Before recommending strategy changes |
| Compose Compiler Reports | Unstable params into `AndroidView` update | When update block recomposes every frame |

---

## When to Use

Load this skill when:

- Hosting **Compose inside Views** (`ComposeView`, XML, Fragment, Dialog, RecyclerView ViewHolder, ViewPager2 page)
- Embedding **Views inside Compose** (`AndroidView`, `AndroidViewBinding`, legacy custom Views)
- Choosing **`ViewCompositionStrategy`** for Fragment, Dialog, or pooling containers
- **RecyclerView** or **ViewPager2** mixes Compose and View children
- **Single-Activity + Fragments** or **multi-Activity** legacy navigation with partial Compose
- Auditing or fixing **performance regressions** during incremental migration (not greenfield Compose-only apps)

---

## When NOT to Use

| User intent | Load instead |
|-------------|--------------|
| Migrate one XML layout end-to-end (10-step workflow) | Google's `migrate-xml-views-to-jetpack-compose` |
| Nav3 scenes, `AndroidFragment`, `NavDisplay` | `compose-navigation-nav3` (v1 interop defers Nav3 — see Follow-up) |
| Unstable params / skipping inside pure Compose | `compose-composition-core` |
| `LaunchedEffect`, `DisposableEffect`, coroutines at boundary | `compose-effects` |
| ViewModel scope, UiState, Screen/Content split | `compose-architecture` |
| Accessibility on merged trees | `compose-quality` |
| Full project recomposition audit | `compose-audit` → routes `INTEROP-*` here |

### v1 exclusions (androidx only)

- **No Accompanist** — use androidx ViewPager2, Compose, `ui-viewbinding` only
- **No Nav3 `AndroidFragment` / scene recipes** — follow-up change
- **No CMP desktop View interop**

---

## CMP Applicability

> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)

> ⚠️ **This skill is Android-only.** All APIs (`AndroidView`, `ComposeView`, `ViewCompositionStrategy`, `RecyclerView`, `Fragment`) use `android.view.View`. There is no CMP equivalent of this skill.

| Source set | Status | Notes |
|------------|--------|-------|
| `commonMain` | ❌ | No `android.view.View` in commonMain — the entire skill is out of scope |
| `androidMain` | ✅ | Full skill content applies |
| `iosMain` | ❌ | Use `UIKitView`, `UIKitViewController`, `ComposeUIViewController` — outside this skill's scope |
| `desktopMain` | ❌ | Use `SwingPanel` / `SwingInterop` — outside this skill's scope |
| `wasmJsMain` | ❌ | Use `HtmlView` (experimental) — outside this skill's scope |

**Status legend**: ✅ fully supported · ⚠️ partial / version-gated · ❌ Android-only.

**CMP scope**: This skill covers **Android View interop ONLY**. For iOS embedding (`UIKitView`, `ComposeUIViewController`), desktop (`SwingPanel`), or web (`HtmlView`), see [`../_shared/cmp-platform.md#7-view-interop-across-platforms`](../_shared/cmp-platform.md).

---

## Interop decision tree

```
Need UI in a legacy View host (XML, Fragment, RV ViewHolder, Dialog)?
├── YES → ComposeView + setContent
│   ├── Fragment / Dialog? → ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
│   ├── RecyclerView item? → Default or DisposeOnDetachedFromWindowOrReleasedFromPool + stable setContent (see recycler-view-interop)
│   └── Sole Activity window? → Default often OK
└── NO → Need legacy View inside Compose tree?
    ├── SDK has no Compose API (MapView, WebView, AdView, …)? → AndroidView (factory + lean update)
    ├── Small legacy XML snippet during migration? → AndroidViewBinding (not full-screen)
    ├── Custom View / View DS widget? → AndroidView short-term; plan Compose rewrite (custom-view-wrappers)
    └── UI rebuildable in Compose? → Pure Compose (do NOT use AndroidView)
```

**Source of truth at boundary**: hoist shared state in `ViewModel` / UDF holder; avoid two owners mutating the same View property from Compose and View code.

---

## Critical patterns

### 1. `AndroidView` — factory once, lean `update`

```kotlin
// CORRECT — SDK gap; factory creates View once
AndroidView(
    factory = { context -> MapView(context).apply { /* one-time setup */ } },
    update = { map ->
        // Only sync when camera/bounds actually change — avoid heavy work every recomposition
        if (map.tag != targetBounds) {
            map.moveCamera(targetBounds)
            map.tag = targetBounds
        }
    },
    onRelease = { it.onDestroy() },
    modifier = Modifier.fillMaxSize(),
)

// WRONG — remembers View outside AndroidView; update does heavy allocation
val view = remember { MyChartView(context) }
AndroidView(factory = { view }, update = { it.rebuild(chartData) }) // rebuild every recomposition
```

See [references/android-view-in-compose.md](references/android-view-in-compose.md).

### 2. `ComposeView` — match `ViewCompositionStrategy` to host

| Host | Strategy | Why |
|------|----------|-----|
| Fragment `onCreateView` | `DisposeOnViewTreeLifecycleDestroyed` | Align with `viewLifecycleOwner`; avoid state loss on back stack |
| `DialogFragment` / BottomSheet | `DisposeOnViewTreeLifecycleDestroyed` | Window lifecycle; see dialog reference |
| `RecyclerView` ViewHolder | `DisposeOnDetachedFromWindowOrReleasedFromPool` (default) | Pooling-safe disposal |
| Activity-only `ComposeView` in XML | Default often OK | Detach from window disposes |

```kotlin
composeView.setViewCompositionStrategy(
    ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
)
composeView.setContent {
    MaterialTheme { ProfileContent() }
}
```

**Anti-pattern**: calling `setContent { }` on every `onBindViewHolder` — use stable content and pass state via parameters. See [references/recycler-view-interop.md](references/recycler-view-interop.md).

### 3. Lazy list `AndroidView` — enable reuse (Compose 1.4+)

```kotlin
AndroidView(
    factory = { ctx -> MyView(ctx) },
    update = { it.bind(item) },
    onReset = { it.clear() }, // required for reuse in LazyColumn/LazyRow
    onRelease = { it.dispose() },
)
```

### 4. Window insets — one consumer per hierarchy root

- View-root screen: consume insets in View layer; set `ComposeView.consumeWindowInsets = false` when appropriate
- Compose-root screen: consume in Compose; pad `AndroidView` with `Modifier.windowInsetsPadding`

See [android docs — insets Views + Compose](https://developer.android.com/develop/ui/compose/system/insets-views-compose).

### 5. State across boundaries

- **Compose → View**: update block or `SideEffect` / callback from stable hoisted state
- **View → Compose**: listener updates `ViewModel` / `MutableState` held above interop node
- **Never**: duplicate source of truth on both sides without a single owner

See [references/view-binding-bridge.md](references/view-binding-bridge.md) and `compose-architecture` for ViewModel scoping.

### 6. Dialog / BottomSheet hybrids

Use `ComposeView` with fragment/dialog lifecycle strategy; avoid retaining composition after dismiss. Material Compose `Dialog` / `ModalBottomSheet` can coexist during migration — pick one owner per overlay.

See [references/dialog-bottomsheet-hybrids.md](references/dialog-bottomsheet-hybrids.md).

### 7. Topology guides

| Topology | Reference |
|----------|-----------|
| Single Activity + Fragment back stack | [single-activity-fragments.md](references/single-activity-fragments.md) |
| Multiple Activities | [multi-activity-patterns.md](references/multi-activity-patterns.md) |
| RecyclerView ↔ Compose | [recycler-view-interop.md](references/recycler-view-interop.md) |
| ViewPager2 pages | [viewpager2-interop.md](references/viewpager2-interop.md) |

---

## Anti-patterns (quick reference)

| Anti-pattern | Phase / risk | Fix |
|--------------|--------------|-----|
| `AndroidView` for Button/Text you can write in Compose | Composition tax forever | Migrate UI to Compose |
| Heavy work in `AndroidView` `update` | Composition every state tick | Diff updates; hoist stable ids |
| `setContent` in RV `onBind` every bind | Critical jank | One composition per holder; update state |
| Default strategy in Fragment | State loss / leaks | `DisposeOnViewTreeLifecycleDestroyed` |
| `remember { View() }` outside `AndroidView` | Stale context / leaks | Create in `factory` |
| Two scroll parents without nested connection | Layout jank | `nestedScroll` bridge or single scroller |
| Profile debug hybrid screen | False conclusions | Release + Macrobenchmark |

---

## Commands

```bash
# Validate official interop guidance
android docs search "ComposeView ViewCompositionStrategy"
android docs fetch "kb://android/develop/ui/compose/migrate/interoperability-apis/views-in-compose"

# Audit signals in consumer apps
rg -n 'AndroidView\s*\(' -t kotlin
rg -n 'ComposeView|setViewCompositionStrategy' -t kotlin
rg -n 'setContent\s*\{' -t kotlin --glob '*ViewHolder*'
```

---

## Related skills

| Skill | Relationship |
|-------|--------------|
| `migrate-xml-views-to-jetpack-compose` (Google) | Per-screen migration workflow |
| `compose-composition-core` | Stability, skipping, deferred reads |
| `compose-architecture` | ViewModel scope at screen root |
| `compose-effects` | `DisposableEffect` for View listeners |
| `compose-audit` | `INTEROP-*` patterns route here |

---

## Follow-up (out of v1)

**Nav3 bridge**: replacing Fragment/ViewPager2 Compose hosts with `NavDisplay`, scene strategies, and dialog scenes — coordinate with `compose-navigation-nav3`; do not duplicate Nav3 API docs here.

---

## Resources

| Reference | Topic |
|-----------|--------|
| [references/README.md](references/README.md) | Index |
| [android-view-in-compose.md](references/android-view-in-compose.md) | `AndroidView`, lazy reuse, SDK-only |
| [compose-view-in-views.md](references/compose-view-in-views.md) | `ComposeView`, strategies |
| [recycler-view-interop.md](references/recycler-view-interop.md) | RV ViewHolder, `AndroidView` in Lazy |
| [viewpager2-interop.md](references/viewpager2-interop.md) | Off-screen pages, nested scroll |
| [dialog-bottomsheet-hybrids.md](references/dialog-bottomsheet-hybrids.md) | Dialog/BottomSheet lifecycle |
| [single-activity-fragments.md](references/single-activity-fragments.md) | Fragment back stack |
| [multi-activity-patterns.md](references/multi-activity-patterns.md) | Activity transitions |
| [view-binding-bridge.md](references/view-binding-bridge.md) | ViewBinding + ComposeView |
| [custom-view-wrappers.md](references/custom-view-wrappers.md) | Custom Views, View DS |
| [interop-performance-checklist.md](references/interop-performance-checklist.md) | Verify hybrid screens |

Official: [Interoperability APIs](https://developer.android.com/develop/ui/compose/migrate/interoperability-apis), [Compare metrics](https://developer.android.com/develop/ui/compose/migrate/compare-metrics).
