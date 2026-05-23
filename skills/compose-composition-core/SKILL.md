---
name: compose-composition-core
description: >
  Jetpack Compose composition internals: state management, recomposition mechanics,
  stability, component identity, CompositionLocal, and the 3-phase performance model.
  Trigger: when working with Compose state, recomposition bugs, derivedStateOf, remember variants,
  stability annotations, LazyList performance, or CompositionLocal.
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

### State Hoisting + Lambda-Deferred Read

```kotlin
// Parent holds the state but does NOT read it in body
@Composable
fun ParentScreen() {
    val scrollOffset by rememberInfiniteTransition().animateFloat(
        initialValue = 0f, targetValue = 300f,
        animationSpec = infiniteRepeatable(tween(1000))
    )

    // Pass lambda — child decides WHEN to read (layout phase, not composition)
    OffsetBox(offsetProvider = { scrollOffset })
}

@Composable
fun OffsetBox(offsetProvider: () -> Float) {
    Box(
        Modifier
            // ✅ Reads in layout phase — no recomposition of OffsetBox
            .offset { IntOffset(0, offsetProvider().roundToInt()) }
            .size(100.dp)
            .background(Color.Blue)
    )
}

// ❌ Anti-pattern: reads in Composition, forces OffsetBox to recompose every frame
@Composable
fun OffsetBoxBad(offset: Float) {
    Box(Modifier.offset(0.dp, offset.dp).size(100.dp).background(Color.Blue))
}
```

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
- A composable recomposes more than expected (excess invalidation, jank)
- Deciding between `remember`, `rememberSaveable`, `retain`, or `rememberSerializable`
- Using `derivedStateOf` and unsure if it is the right tool
- Debugging unexpected state loss after configuration changes or process death
- Working with `CompositionLocal` and unsure which variant to choose
- Optimizing `LazyColumn`/`LazyRow` for reorder or insert/delete
- Reviewing stability of custom classes and deciding when to apply `@Stable`/`@Immutable`

---

## When to Use This vs compose-effects

`compose-composition-core` covers state lifecycle, recomposition mechanics, and stability decisions — everything that happens during the Composition phase and its identity model.

`compose-effects` covers `LaunchedEffect`, `DisposableEffect`, `SideEffect`, and `snapshotFlow` — operations triggered BY composition but that run outside it (coroutines, subscriptions, cleanup).

Use both when: reading a `StateFlow` inside a composable (`collectAsStateWithLifecycle` bridges them), or when `derivedStateOf` inside `remember` is combined with `snapshotFlow`.

---

## Critical Patterns

### 1. 3-Phase Lambda Deferral

The fastest recomposition is the one that never happens. Pass `() -> T` when the parent holds state but the child is the only one that renders it.

```kotlin
// ✅ Scroll offset read deferred to Layout phase
Modifier.offset { IntOffset(0, scrollState.value) }

// ❌ Read in Composition — recomposes the whole scope on every scroll tick
Modifier.offset(scrollState.value.dp)
```

Only use provider lambdas (`() -> T`) when you have a measured performance problem. They add lambda allocation overhead and reduce readability. Always measure before and after.

### 2. `derivedStateOf` — Only When Output Changes Less Than Input

`derivedStateOf` creates a snapshot state whose recomposition scope fires only when the RESULT changes, not every time an input changes.

```kotlin
// ✅ Correct: isAtTop changes rarely; firstVisibleItemIndex changes on every scroll tick
val isAtTop by remember { derivedStateOf { listState.firstVisibleItemIndex == 0 } }

// ❌ Wrong: output equals input — no filtering benefit, just extra overhead
val name by remember { derivedStateOf { user.name } }
```

**Key rule**: component parameters are NOT snapshot state — they cannot be observed by `derivedStateOf`. When `derivedStateOf` depends on a parameter, that parameter MUST be a `remember` key.

```kotlin
// ❌ Bug: threshold changes are silently ignored
val enabled by remember { derivedStateOf { password.length > threshold } }

// ✅ Fix: threshold is a remember key
val enabled by remember(threshold) { derivedStateOf { password.length > threshold } }
```

### 3. Backwards-Write Warning

> **CRITICAL**: Writing MutableState inside a composable body triggers another recomposition immediately, creating an infinite loop. This is one of the most dangerous patterns in Compose.

```kotlin
// ❌ Infinite recomposition loop — DO NOT do this
@Composable
fun BadComposable() {
    var count by remember { mutableStateOf(0) }
    Text("Count: $count")
    count++ // backwards write — composition → write → recomposition → write → ...
}

// ✅ Writes belong in event handlers or effects
@Composable
fun GoodComposable() {
    var count by remember { mutableStateOf(0) }
    Text("Count: $count")
    Button(onClick = { count++ }) { Text("Increment") }
}
```

### 4. `remember(key)` for Expensive Computations

`remember` without keys is a permanent cache — it never updates if inputs change.

```kotlin
// ❌ Stale cache — if users changes, sortedUsers never updates
val sortedUsers = remember { users.sortedBy { it.name } }

// ✅ Keys are exhaustive — cache invalidates when any input changes
val sortedUsers = remember(users, comparator) { users.sortedWith(comparator) }
```

Do NOT add snapshot state reads as keys. Snapshot state is observed automatically inside the `remember` lambda; adding it as a key triggers full reinitialization instead of the cheaper read-update cycle.

### 5. LazyList Key — Mandatory for Correct Identity

Without a key, LazyColumn uses index-based identity. Inserting or removing an item shifts all indices below it, causing full recomposition of every shifted item.

```kotlin
// ❌ Index identity — insert at top recomposes ALL items
LazyColumn {
    items(items) { item -> ItemRow(item) }
}

// ✅ Stable key identity — only the changed item recomposes
LazyColumn {
    items(items, key = { it.id }) { item -> ItemRow(item) }
}
```

Key constraints: must be unique among siblings; on Android, must be a `Bundle`-storable type (`String`, `Int`, etc.); must remain stable for the same logical item.

### 6. `Modifier.offset { lambda }` vs `Modifier.offset(value)`

See Pattern 1 and the Code Examples section for the full contrast. The short rule: any rapidly-changing state (animations, scroll offsets) that affects only position/transform belongs in a lambda overload to confine the read to the Layout or Drawing phase.

### 7. State Lifespan Ladder

| Function | Survives Recomposition | Survives Config Change | Survives Process Death | Accepts Non-Serializable |
|----------|----------------------|----------------------|----------------------|--------------------------|
| `remember` | Yes | No | No | Yes |
| `retain` | Yes | Yes | No | Yes |
| `rememberSaveable` | Yes | Yes | Yes (Bundle types) | No (needs Saver) |
| `rememberSerializable` | Yes | Yes | Yes (Java serialization) | No |

- Use `remember` for transient UI state (expansion, focus, interaction source).
- Use `retain` for heavy non-serializable objects that must survive rotation (e.g., `ExoPlayer`).
- Use `rememberSaveable` for user-entered input and UI state that must survive system-initiated process death.
- Use `rememberSerializable` only when you have no other option — Java serialization is fragile.

> **Stability note for `retain`**: available in Compose runtime snapshots; verify your BOM version before use. `rememberSerializable` is not yet in stable Compose as of 2026-05; check BOM release notes.

### 8. Strong Skipping Mode

Default since Kotlin 2.0.20. Key behavior changes:

- Unstable types are now compared by reference (`===`) instead of being treated as always-changed. This eliminates many false recompositions.
- ALL lambdas in composable functions are automatically wrapped in `remember { }` with their captured variables as keys. Lambda identity is stable unless captured variables change.
- To opt out of lambda memoization for a specific lambda, annotate with `@DontMemoize`.

```kotlin
// Under Strong Skipping Mode, this lambda is automatically memoized:
@Composable
fun Screen(viewModel: ScreenViewModel) {
    ItemList(onClick = { viewModel.onItemClick(it) })
    // Equivalent to: onClick = remember(viewModel) { { viewModel.onItemClick(it) } }
}
```

> **Profiling note**: debug builds disable Strong Skipping. ALWAYS profile release builds.

### 9. CompositionLocal

`CompositionLocal` propagates values implicitly down the composition tree. Choose the variant based on how often the value changes.

| Variant | Recomposition on change | Use When |
|---------|------------------------|----------|
| `compositionLocalOf` | Only direct readers recompose | Value changes at runtime (theme colors, locale) |
| `staticCompositionLocalOf` | ENTIRE subtree recomposes | Value is effectively constant after first provision |

```kotlin
// ✅ For frequently changing values: only readers recompose
val LocalThemeMode = compositionLocalOf { ThemeMode.Light }

// ✅ For static values: cheaper read, but ANY change recomposes the whole subtree
val LocalAppConfig = staticCompositionLocalOf<AppConfig> { error("No AppConfig provided") }

// Usage (same for both)
CompositionLocalProvider(LocalThemeMode provides ThemeMode.Dark) {
    // All children can read LocalThemeMode.current
    ChildComposable()
}
```

> Do NOT use `CompositionLocal` as a substitute for parameter passing in non-cross-cutting concerns. Reserve it for framework-level values (theme, locale, window info) that would otherwise require threading through many composable layers.

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| Reading rapidly-changing state in composable body | Pass `() -> T` lambda; child reads in layout/draw phase | Composition → Layout (full scope eliminated) |
| `derivedStateOf` wrapping every state | Only use when output changes less than inputs | CPU overhead with no recomposition benefit |
| `val x = remember { expensiveCalc(input) }` without key | `remember(input) { expensiveCalc(input) }` | Stale cache, wrong data shown |
| Writing MutableState in composable body | Move writes to event handlers, LaunchedEffect, SideEffect | Infinite recomposition loop |
| `items(list)` without key in LazyColumn | `items(list, key = { it.id })` | Full Composition on reorder |
| `Modifier.offset(scrollState.value.dp)` | `Modifier.offset { IntOffset(0, scrollState.value) }` | Composition eliminated; Layout only |
| `staticCompositionLocalOf` for frequently-changing values | `compositionLocalOf` — only readers recompose | Whole subtree Composition vs. just readers |

---

## Code Examples

### State Hoisting — Pass Only What Each Child Needs

```kotlin
// ❌ Entire uiState passed down — any field change recomposes all children
@Composable
fun ChatScreen(vm: ChatViewModel) {
    val uiState by vm.uiState.collectAsStateWithLifecycle()
    ChatTopBar(uiState)
    ChatMessages(uiState)
    ChatBottomBar(uiState)
}

// ✅ Each child receives only its slice — unrelated changes skip recomposition
@Composable
fun ChatScreen(vm: ChatViewModel) {
    val uiState by vm.uiState.collectAsStateWithLifecycle()
    ChatTopBar(loading = uiState.loading)
    ChatMessages(messages = uiState.messages)
    ChatBottomBar(
        text = uiState.messageInput,
        onTextChange = vm::onInputChanged,
        onSend = vm::onSend,
    )
}
```

### `derivedStateOf` with Scroll State

```kotlin
@Composable
fun ContactsScreen(contacts: PersistentList<String>) {
    val gridState = rememberLazyGridState()

    // isAtTop only changes when crossing the boundary — not on every scroll tick
    val isAtTop by remember { derivedStateOf { gridState.firstVisibleItemIndex == 0 } }

    Scaffold(
        floatingActionButton = {
            if (!isAtTop) ScrollToTopFab(gridState)
        }
    ) { padding ->
        ContactsGrid(gridState, contacts, Modifier.padding(padding))
    }
}
```

### Hoisted State Type with `derivedStateOf`

```kotlin
@Stable
class MapState {
    private val _location = mutableStateOf<Position?>(null)
    // Each derived property has its own recomposition scope
    val latitude by derivedStateOf { _location.value?.latitude }
    val longitude by derivedStateOf { _location.value?.longitude }

    fun move(position: Position) { _location.value = position }
}
```

### `retain` for Heavy Non-Serializable Objects

```kotlin
@Composable
fun VideoPlayer() {
    val context = LocalContext.current.applicationContext
    val player = retain {
        ExoPlayer.Builder(context).build()
    }
    // player survives rotation; is released when composition leaves permanently
}
```

### LazyColumn with Stable Keys

```kotlin
LazyColumn {
    items(
        items = todos,
        key = { it.id },      // stable, Bundle-compatible
    ) { todo ->
        TodoRow(todo)
    }
}
```

---

## Commands

```bash
# Generate compiler stability report
./gradlew assembleRelease  # then check build/compose_compiler/

# Enable in build.gradle.kts:
# composeCompiler {
#     reportsDestination = layout.buildDirectory.dir("compose_compiler")
#     metricsDestination = layout.buildDirectory.dir("compose_compiler")
# }

# Check for new unstable types introduced in a PR (CI gate)
grep "unstable" build/compose_compiler/*-classes.txt
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-modifier-system` | `../compose-modifier-system/SKILL.md` | How modifiers interact with layout/drawing phases |
| `compose-effects` | `../compose-effects/SKILL.md` | Coroutine effects that read/write composition state |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/snapshot-state-and-recomposition.md](references/snapshot-state-and-recomposition.md) | Snapshot state, remember ladder, recomposition propagation |
| [references/derived-state.md](references/derived-state.md) | `derivedStateOf` rules and keys trap |
| [references/stability-and-skipping.md](references/stability-and-skipping.md) | Stability categories, Strong Skipping Mode |
| [references/component-identity.md](references/component-identity.md) | Identity, `key`, LazyList keys, `movableContentOf` |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx, Strong Skipping Mode (default)
- **Stable APIs**: `remember`, `rememberSaveable`, `derivedStateOf`, `CompositionLocal`, `key()`
- **Experimental/Alpha**: `retain` — available in Compose runtime snapshots; verify BOM version before use. `rememberSerializable` — not yet in stable Compose as of 2026-05; check BOM release notes.
- **Review cadence**: Quarterly
