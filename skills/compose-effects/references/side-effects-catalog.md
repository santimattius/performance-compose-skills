# Side Effects Catalog

## Decision Tree — Which Effect?

```
Need to run suspend work tied to composition lifecycle?
├── YES → Need cleanup on leave/key change?
│   ├── YES → DisposableEffect + onDispose { cleanup }
│   └── NO  → LaunchedEffect
└── NO → Need coroutine on user click?
    ├── YES → rememberCoroutineScope().launch { }
    └── NO → Need sync non-Compose object after recomposition?
        ├── YES (cheap, low frequency) → SideEffect
        └── NO → Not an effect — use event handler or derivedStateOf
```

## `LaunchedEffect`

- Runs suspend block when entering composition; cancels when leaving or keys change
- **Keys must be exhaustive** — every variable read inside MUST be a key

```kotlin
LaunchedEffect(userId) { loadUser(userId) }  // ✅
LaunchedEffect(Unit) { loadUser(userId) }    // ❌ stale userId
```

## `DisposableEffect`

- Setup + mandatory `onDispose { }` that reverses setup
- Empty `onDispose` → wrong effect; use `LaunchedEffect` instead
- Compiler enforces `onDispose` presence

## `rememberUpdatedState`

Keep effect keys stable while callbacks stay current:

```kotlin
val latestCallback by rememberUpdatedState(onTimeout)
LaunchedEffect(Unit) {
    delay(5_000)
    latestCallback()
}
```

## `SideEffect`

Runs after every **successful** recomposition. Use ONLY for cheap non-Compose sync (analytics screen name). **Never** for scroll/animation frequency — use `snapshotFlow`.

## `rememberCoroutineScope`

For event-driven work (button clicks). **Never** launch at composable body top level — runs every recomposition.

## `produceState`

Bridge callback-based or async sources into `State<T>`. Keys like `LaunchedEffect`. Use `awaitDispose { }` for cleanup.

For `StateFlow`/`Flow` → prefer `collectAsStateWithLifecycle`.

## `LaunchedEffect` vs `rememberCoroutineScope`

| | LaunchedEffect | rememberCoroutineScope |
|---|----------------|------------------------|
| Trigger | Enter composition / key change | User event |
| Restarts on key change | Yes | No |
| Use for | Data load, subscriptions | Submit, navigate on click |

## Performance Rule

Reading scroll/list state in composable body → Composition rerun every frame.

**Fix:** `snapshotFlow { state.value }.distinctUntilChanged()` inside `LaunchedEffect` — see [snapshot-flow-and-derived-state.md](snapshot-flow-and-derived-state.md).
