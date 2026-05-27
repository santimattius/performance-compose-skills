---
name: compose-effects
description: >
  Jetpack Compose side effects: LaunchedEffect, DisposableEffect, SideEffect, produceState,
  snapshotFlow, rememberUpdatedState, and derivedStateOf — with keys, cleanup contracts,
  and performance rules. Trigger: when working with LaunchedEffect, DisposableEffect,
  SideEffect, produceState, snapshotFlow, or any coroutine-based effect in Compose.
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

### Defer State Reads (decision tree)

Do you need the value during composition?
- YES → read as `T` (Composition phase) — accept full restart cost
- NO  → can you defer to layout/draw?
  - Layout-only?    → pass `() -> T` into `Modifier.layout`/`offset { }` lambda
  - Draw/transform? → pass `() -> T` into `Modifier.graphicsLayer { }` / `drawBehind { }` lambda

**Rule**: prefer `Modifier.offset { lambda }` over `Modifier.offset(state.value.dp)`. Lambda variant defers the read to the layout phase, skipping recomposition entirely.

### Effects and the Phase Model

Reading `listState.firstVisibleItemIndex` directly in the composable body re-runs the entire composition scope on every scroll pixel — HIGH phase cost, even if the analytics event fires only every N items.

```kotlin
// ❌ Reads in Composition phase — recomposes the whole scope on every scroll tick
@Composable
fun TrackScrollAnalytics(listState: LazyListState, analytics: Analytics) {
    // This runs on EVERY scroll pixel — HIGH phase cost
    val index = listState.firstVisibleItemIndex
    SideEffect { analytics.track("scroll", index) }
}

// ✅ snapshotFlow reads state OUTSIDE the composition phase
// Fires only when firstVisibleItemIndex actually changes (.distinctUntilChanged())
@Composable
fun TrackScrollAnalytics(listState: LazyListState, analytics: Analytics) {
    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()
            .collect { index -> analytics.track("scroll", index) }
    }
}
```

`snapshotFlow` reads Compose state inside a coroutine, outside the Composition phase. The `distinctUntilChanged()` operator ensures downstream processing (analytics, network calls) runs only when the value actually changes — not on every scroll pixel.

---

## Performance Toolchain

> WARNING: NEVER profile in debug builds. Debug disables R8, inlining, and Strong Skipping — numbers are meaningless. Always profile a release build with `profileable` enabled or a benchmark build type.

| Tool | Use For | When |
|------|---------|------|
| Baseline Profiles | AOT-compile critical paths (startup, scroll) | Ship in release; regenerate per release |
| Compose Compiler Reports | Detect unstable params, restartable/skippable status | Every PR; fail CI on new unstable types |
| Layout Inspector (recomposition counts) | See which composables recompose and why | When debugging excess recomposition |
| Composition Tracing | Frame-level composition timing in Android Studio | When Layout Inspector is not enough |
| Macrobenchmark | Measure startup, frame timing, jank in release | Per-release regression gate |

---

## When to Use

Use this skill when:
- Using `LaunchedEffect`, `DisposableEffect`, or `SideEffect` and unsure which fits the situation
- A coroutine must start when a composable enters the composition and cancel when it leaves
- An external resource (observer, listener, subscription) must be registered and cleaned up
- Converting a non-Compose observable source into Compose `State` with `produceState`
- Tracking high-frequency Compose state (scroll position, animation progress) outside composition
- A callback prop updates without wanting to restart an expensive effect
- Deciding between `LaunchedEffect` and `rememberCoroutineScope`

---

## When to Use This vs compose-composition-core

`compose-composition-core` covers state lifecycle, recomposition mechanics, and stability — everything that happens during the Composition phase itself.

`compose-effects` covers operations TRIGGERED by composition but that run OUTSIDE it: coroutines, subscriptions, cleanup, and one-shot side effects.

Use both when:
- `collectAsStateWithLifecycle` bridges a `StateFlow` into composition (architecture concern) while `LaunchedEffect` drives animation or analytics (effects concern)
- `derivedStateOf` inside `remember` (core) is combined with `snapshotFlow` inside `LaunchedEffect` (effects)
- An effect reads `derivedStateOf` output — the derivedStateOf optimization belongs in core, the coroutine reaction belongs here

---

## CMP Applicability

> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)

| Source set | Status | Notes |
|------------|--------|-------|
| `commonMain` | ⚠️ | `LaunchedEffect`, `DisposableEffect`, `SideEffect`, `snapshotFlow` all ✅; `collectAsStateWithLifecycle` version-gated |
| `androidMain` | ✅ | Full skill content applies |
| `iosMain` | ⚠️ | `collectAsStateWithLifecycle` requires `lifecycle-runtime-compose` ≥ 2.8 |
| `desktopMain` | ⚠️ | Same lifecycle version gate; also needs `kotlinx-coroutines-swing` in `jvmMain` |
| `wasmJsMain` | ⚠️ | Same lifecycle version gate |

**Status legend**: ✅ fully supported · ⚠️ partial / version-gated · ❌ Android-only.

**If using in CMP**: `collectAsStateWithLifecycle` requires `androidx.lifecycle:lifecycle-runtime-compose` ≥ 2.8 in `commonMain`. Below 2.8, use `collectAsState()` or a `expect`/`actual` shim. See [`../_shared/cmp-platform.md#4-lifecycle--state-collection`](../_shared/cmp-platform.md).

---

## Critical Patterns

### 1. Keys Must Be Exhaustive

`LaunchedEffect` and `DisposableEffect` restart when ANY key changes. Every variable the effect body reads MUST appear as a key. A stale closure from incomplete keys is the #1 effects bug.

```kotlin
// ❌ Bug: userId changes, but the effect never restarts — stale userId in the coroutine
@Composable
fun UserProfile(userId: String) {
    LaunchedEffect(Unit) { // WRONG key — Unit never changes
        loadUser(userId)   // stale closure — reads the initial userId forever
    }
}

// ✅ Correct: effect restarts whenever userId changes
@Composable
fun UserProfile(userId: String) {
    LaunchedEffect(userId) {
        loadUser(userId)
    }
}
```

**Rule**: if the effect reads it, the effect keys it.

### 2. `rememberUpdatedState` — Callback Updates Without Restarting

When a callback must update silently without restarting an expensive effect, keep the key stable and capture the callback via `rememberUpdatedState`.

```kotlin
// ❌ Problem: every callback lambda change restarts the timer effect
@Composable
fun Timer(onTimeout: () -> Unit) {
    LaunchedEffect(onTimeout) { // callback identity changes on every recomposition
        delay(5_000)
        onTimeout()
    }
}

// ✅ Fix: stable key — callback updates silently inside the long-running effect
@Composable
fun Timer(onTimeout: () -> Unit) {
    val latestOnTimeout by rememberUpdatedState(onTimeout)
    LaunchedEffect(Unit) { // key is stable — effect runs once for the composable's lifetime
        delay(5_000)
        latestOnTimeout() // always calls the latest lambda
    }
}
```

### 3. `DisposableEffect` — Non-Empty `onDispose` Contract

The compiler enforces that `onDispose {}` is present. Its body MUST reverse the registration — remove the observer, cancel the subscription. An empty `onDispose {}` signals the wrong effect choice.

```kotlin
// ✅ Correct: lifecycle observer registered and always removed
@Composable
fun LifecycleObserverEffect(lifecycle: Lifecycle, observer: LifecycleObserver) {
    DisposableEffect(lifecycle) {
        lifecycle.addObserver(observer)
        onDispose {
            lifecycle.removeObserver(observer) // reversal — REQUIRED
        }
    }
}

// ❌ Wrong: empty onDispose → observer is never removed → resource leak
@Composable
fun LeakyEffect(lifecycle: Lifecycle, observer: LifecycleObserver) {
    DisposableEffect(lifecycle) {
        lifecycle.addObserver(observer)
        onDispose {} // empty → use LaunchedEffect if you have no cleanup
    }
}
```

**Decision**: if you have no cleanup, use `LaunchedEffect`. `DisposableEffect` exists ONLY when cleanup is required.

### 4. `snapshotFlow` + `distinctUntilChanged()`

`snapshotFlow` converts Compose state into a Flow with full Flow operators. It reads state outside the Composition phase. Always pair with `.distinctUntilChanged()` to prevent redundant downstream processing.

```kotlin
@Composable
fun ScrollTracker(listState: LazyListState) {
    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()         // skip if index did not actually change
            .filter { index -> index > 0 }  // Flow operators compose freely
            .collect { index ->
                // Fires only when firstVisibleItemIndex changes to a value > 0
                analytics.track("scroll_past_top", index)
            }
    }
}
```

Prefer `snapshotFlow` over `SideEffect` for any state that changes at scroll/animation frequency. `SideEffect` runs after EVERY recomposition — `snapshotFlow` runs only when the observed value changes.

### 5. `derivedStateOf` Inside `remember` — Mandatory Wrapper

`val showButton by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }`. The `remember` wrapper is mandatory — without it, a new `derivedStateOf` object is created on every recomposition, defeating the optimization entirely.

```kotlin
// ✅ Correct: one derivedStateOf object, recomposes only when boolean result flips
@Composable
fun ScrollToTopButton(listState: LazyListState) {
    val showButton by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }
    if (showButton) { /* render button */ }
}

// ❌ Bug: new derivedStateOf on every recomposition — no optimization, extra object allocation
@Composable
fun ScrollToTopButtonBad(listState: LazyListState) {
    val showButton by derivedStateOf { listState.firstVisibleItemIndex > 0 }
    if (showButton) { /* render button */ }
}
```

Only use `derivedStateOf` when the output changes LESS FREQUENTLY than the inputs.

### 6. `SideEffect` — Lightweight Only

`SideEffect` runs after every SUCCESSFUL recomposition. Use exclusively for synchronizing non-Compose objects with the current composition state (analytics user properties, external SDK state).

```kotlin
// ✅ Correct: analytics user property stays in sync with composition state
@Composable
fun TrackCurrentScreen(screenName: String, analytics: Analytics) {
    SideEffect {
        analytics.setCurrentScreen(screenName) // cheap, non-Compose sync
    }
}
```

**NEVER** use `SideEffect` for high-frequency state (scroll position, animation progress). Use `snapshotFlow` inside `LaunchedEffect` instead. `SideEffect` has no filtering — it fires on every recomposition.

### 7. `LaunchedEffect` vs `rememberCoroutineScope`

Both launch coroutines. The choice depends on what drives the work:

| | `LaunchedEffect` | `rememberCoroutineScope` |
|---|---|---|
| **Trigger** | Composable entering composition | User event (button click) |
| **Cancellation** | Keys change OR composable leaves | Composable leaves |
| **Key control** | YES — restart on key change | NO — runs until scope cancelled |
| **Use for** | Lifecycle-scoped work (data load, animation) | Event-driven work (submit, navigate) |

```kotlin
// ✅ LaunchedEffect — starts with composable, restarts when userId changes
@Composable
fun ProfileScreen(userId: String, viewModel: ProfileViewModel) {
    LaunchedEffect(userId) {
        viewModel.loadProfile(userId)
    }
}

// ✅ rememberCoroutineScope — event-driven, tied to button click
@Composable
fun SubmitButton(viewModel: FormViewModel) {
    val scope = rememberCoroutineScope()
    Button(onClick = {
        scope.launch { viewModel.submit() } // fires on click, not on composition
    }) { Text("Submit") }
}

// ❌ Wrong: rememberCoroutineScope for lifecycle work — no restart on key change
@Composable
fun ProfileScreenBad(userId: String, viewModel: ProfileViewModel) {
    val scope = rememberCoroutineScope()
    scope.launch { viewModel.loadProfile(userId) } // called on EVERY recomposition
}
```

### 8. `produceState` — External Observable Sources

Converts non-Compose observable sources (callbacks, futures, Rx) into Compose `State`. Keys behave identically to `LaunchedEffect` keys.

```kotlin
// ✅ Convert a callback-based API into Compose State
@Composable
fun locationState(locationManager: LocationManager): State<Location?> =
    produceState<Location?>(initialValue = null, locationManager) {
        val listener = LocationListener { location -> value = location }
        locationManager.requestLocationUpdates(listener)
        awaitDispose { locationManager.removeUpdates(listener) } // cleanup on key change
    }
```

`produceState` is the idiomatic bridge for non-Flow, non-StateFlow observable sources. For `StateFlow` and `SharedFlow`, prefer `collectAsStateWithLifecycle` from the `lifecycle-runtime-compose` artifact.

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| Reading `listState.firstVisibleItemIndex` in composable body | `snapshotFlow { listState.firstVisibleItemIndex }.distinctUntilChanged()` in `LaunchedEffect` | Eliminates Composition rerun on every scroll pixel |
| `LaunchedEffect(Unit)` with variables that change | Keys = all variables the effect reads | Stale closure — effect never sees new values |
| Callback updates force effect restart | `rememberUpdatedState(callback)` — key stays stable, callback updates silently | Prevents costly effect cancel/relaunch |
| `DisposableEffect` with empty `onDispose {}` | Use `LaunchedEffect` if no cleanup needed; add real cleanup to `onDispose` | Resource leak (observer never removed) |
| `SideEffect { analytics.track(state) }` on scroll | `snapshotFlow { state }.distinctUntilChanged().collect { analytics.track(it) }` | Composition overhead on every frame |
| `derivedStateOf { ... }` missing `remember` wrapper | Always wrap: `val x by remember { derivedStateOf { ... } }` | New derivedStateOf object every recomposition |
| Long I/O work in `LaunchedEffect` on `Dispatchers.Main` | Switch to `Dispatchers.IO` inside; write state back on Main | Main thread block → UI jank |

---

## Code Examples

### Full Pattern: Scroll Analytics with `snapshotFlow`

```kotlin
@Composable
fun ProductList(
    products: List<Product>,
    analytics: Analytics
) {
    val listState = rememberLazyListState()

    // ✅ snapshotFlow: reads outside Composition, fires only on actual change
    LaunchedEffect(listState) {
        snapshotFlow { listState.firstVisibleItemIndex }
            .distinctUntilChanged()
            .collect { index -> analytics.track("visible_product", products[index].id) }
    }

    // ✅ derivedStateOf: show button only when boolean flips (not every scroll pixel)
    val showScrollToTop by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }

    Box {
        LazyColumn(state = listState) {
            items(products, key = { it.id }) { product ->
                ProductCard(product)
            }
        }
        if (showScrollToTop) {
            ScrollToTopButton(onClick = { /* scope.launch { listState.animateScrollToItem(0) } */ })
        }
    }
}
```

### Full Pattern: Lifecycle Observer with `DisposableEffect`

```kotlin
@Composable
fun LifecycleAwareScreen(
    lifecycle: Lifecycle = LocalLifecycleOwner.current.lifecycle,
    onResume: () -> Unit,
    onPause: () -> Unit
) {
    // ✅ rememberUpdatedState: callbacks update silently without restarting the effect
    val latestOnResume by rememberUpdatedState(onResume)
    val latestOnPause by rememberUpdatedState(onPause)

    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> latestOnResume()
                Lifecycle.Event.ON_PAUSE  -> latestOnPause()
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) } // mandatory cleanup
    }
}
```

### Full Pattern: `produceState` for Callback API

```kotlin
@Composable
fun NetworkStatusBanner(connectivityManager: ConnectivityManager) {
    val isConnected by produceState(initialValue = true, connectivityManager) {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) { value = true }
            override fun onLost(network: Network) { value = false }
        }
        connectivityManager.registerDefaultNetworkCallback(callback)
        awaitDispose { connectivityManager.unregisterNetworkCallback(callback) }
    }

    if (!isConnected) {
        Banner(message = "No internet connection")
    }
}
```

---

## Commands

There are no CLI commands specific to Compose effects. Use the Performance Toolchain above:

- **Compose Compiler Reports**: add `freeCompilerArgs += ["-P", "plugin:androidx.compose.compiler.plugins.kotlin:reportsDestination=..."]` to `build.gradle.kts` — identifies restartable/skippable composable status.
- **Layout Inspector**: In Android Studio → View → Tool Windows → Layout Inspector. Use recomposition counts to verify `snapshotFlow` + `distinctUntilChanged()` reduces recompositions vs. direct state reads.

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | State fundamentals, derivedStateOf, remember — effects build on these |
| `compose-animations` | `../compose-animations/SKILL.md` | Animation effects that use LaunchedEffect + Animatable |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/side-effects-catalog.md](references/side-effects-catalog.md) | Effect selection, LaunchedEffect, DisposableEffect, produceState |
| [references/snapshot-flow-and-derived-state.md](references/snapshot-flow-and-derived-state.md) | `snapshotFlow`, `derivedStateOf`, `rememberUpdatedState` |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx
- **Stable APIs**: `LaunchedEffect`, `DisposableEffect`, `SideEffect`, `produceState`, `rememberUpdatedState`, `rememberCoroutineScope`, `snapshotFlow`, `derivedStateOf`
- **Experimental/Alpha**: None in this skill
- **Compiler note**: `DisposableEffect` compiler enforcement — `onDispose {}` block is required by the Compose compiler; omitting it is a compile error
- **Review cadence**: Quarterly
