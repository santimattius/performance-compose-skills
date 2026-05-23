# Derived State

`derivedStateOf` creates snapshot state computed from other snapshot states.

## Two Benefits

1. **Limits recomposition scope** — defines its own observing scope separate from parent.
2. **Filters updates** — recomposes only when the **result** changes (equality check), not every input tick.

## When to Use

| Scenario | Use `derivedStateOf`? |
|----------|----------------------|
| Scroll position → boolean (`isAtTop`) | ✅ output changes rarely |
| `user.name` from stable `user` | ❌ output equals input — no benefit |
| Hoisted state holder: derived property from backing state | ✅ prevents unrelated property changes from invalidating readers |

## Scroll Pattern

```kotlin
// ❌ Reads index in parent — recomposes parent on every scroll tick
val isAtTop = listState.firstVisibleItemIndex == 0

// ✅ Recomposes only when boolean flips
val isAtTop by remember { derivedStateOf { listState.firstVisibleItemIndex == 0 } }
```

Alternative: read `firstVisibleItemIndex` directly in the narrow scope that needs it (e.g., FAB lambda).

## Mandatory `remember` Wrapper

```kotlin
val show by remember { derivedStateOf { listState.firstVisibleItemIndex > 0 } } // ✅
val show by derivedStateOf { ... }                                               // ❌ new object every recomposition
```

## The Keys Trap — CRITICAL

`derivedStateOf` observes **snapshot state only**, NOT composable parameters.

```kotlin
// ❌ threshold changes ignored — stale closure
val enabled by remember { derivedStateOf { password.length > threshold } }

// ✅ threshold is a remember key
val enabled by remember(threshold) { derivedStateOf { password.length > threshold } }
```

**Rule:** parameters → `remember` keys. Snapshot reads → inside `derivedStateOf` lambda (never as keys).

## Hoisted State Holder Pattern

```kotlin
class MapState {
    private val _location = mutableStateOf<Position?>(null)
    val latitude by derivedStateOf { _location.value?.latitude }  // reader recomposes only if latitude changes
    val longitude get() = _location.value?.longitude              // reader recomposes on ANY _location change
}
```

Use `derivedStateOf` for derived properties when readers should NOT react to unrelated backing-state changes.
