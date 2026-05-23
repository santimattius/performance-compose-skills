# Snapshot Flow and Derived State in Effects

## `snapshotFlow`

Converts Compose snapshot state reads into a Kotlin `Flow`. Reads happen outside Composition phase.

```kotlin
LaunchedEffect(listState) {
    snapshotFlow { listState.firstVisibleItemIndex }
        .distinctUntilChanged()
        .filter { it > 0 }
        .collect { index -> analytics.track("scrolled", index) }
}
```

**Always** pair with `.distinctUntilChanged()` unless every emission is intentional.

### vs `SideEffect`

| | snapshotFlow | SideEffect |
|---|-------------|------------|
| Frequency | Only on value change | Every recomposition |
| Use for | Scroll, animation progress | Analytics screen sync |

### vs Reading in Composable Body

```kotlin
// ❌ Recomposes parent every scroll tick
if (listState.firstVisibleItemIndex > 0) { Fab() }

// ✅ Composition: derivedStateOf for UI visibility
val showFab by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }

// ✅ Side channel: snapshotFlow in LaunchedEffect for analytics/logging
```

## `derivedStateOf` in Effects Context

When UI needs filtered boolean from frequent input:

```kotlin
val showButton by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } }
```

Mandatory `remember` wrapper. Only when output changes **less frequently** than input.

Parameter dependency → `remember(param) { derivedStateOf { ... } }`.

## `rememberUpdatedState` + Long-Running Effect

Pattern for timers, polling, WebSocket handlers that must call latest callback without restarting:

```kotlin
val onEvent by rememberUpdatedState(onEvent)
LaunchedEffect(connectionId) {
    connect(connectionId) { msg -> onEvent(msg) }  // always latest onEvent
}
```

## `DisposableEffect` + Flow Collection

Prefer `LaunchedEffect` for Flow collection. Use `DisposableEffect` only when platform API requires explicit unregister in `onDispose`.

## Common Bugs

| Bug | Fix |
|-----|-----|
| `LaunchedEffect(Unit)` with changing params | Add all read variables as keys |
| `SideEffect` for scroll tracking | `snapshotFlow` + `LaunchedEffect` |
| `derivedStateOf` without `remember` | Wrap in `remember { derivedStateOf { } }` |
| `scope.launch { }` in composable body | `LaunchedEffect` or move to onClick |
