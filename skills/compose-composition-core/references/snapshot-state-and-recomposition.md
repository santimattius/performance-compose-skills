# Snapshot State and Recomposition

## Three Phases

Composition builds the UI tree. Layout measures and places nodes. Drawing renders pixels. **Recomposition** updates existing nodes when snapshot state **readers** change — it does not rebuild the whole tree.

## Snapshot State Rules

- Mutable UI state MUST use snapshot state (`mutableStateOf`, `mutableIntStateOf`, etc.).
- Wrap in `remember { }` so state survives recomposition.
- Reads trigger recomposition scope registration; writes invalidate readers, not writers.

```kotlin
var count by remember { mutableIntStateOf(0) } // ✅
var count by mutableStateOf(0)                 // ❌ reinitializes every recomposition
```

## State Lifespan Ladder

| API | Recomposition | Config change | Process death | Non-serializable |
|-----|---------------|---------------|---------------|------------------|
| `remember` | ✅ | ❌ | ❌ | ✅ |
| `retain` | ✅ | ✅ | ❌ | ✅ |
| `rememberSaveable` | ✅ | ✅ | ✅ (Bundle types) | Needs `Saver` |
| `rememberSerializable` | ✅ | ✅ | ✅ (Java serialization) | ❌ prefer saveable |

**When to use what:**
- Transient UI (expansion, focus) → `remember`
- Heavy objects surviving rotation (`ExoPlayer`) → `retain`
- User input / UI state surviving process death → `rememberSaveable`
- `rememberSerializable` → last resort only

## `remember` Keys

Keys decide when cached values rebuild. Include every **parameter** used in the calculation. Do NOT add snapshot state reads as keys — they are observed inside the lambda.

```kotlin
val sorted = remember(users, comparator) { users.sortedWith(comparator) } // ✅
val sorted = remember { users.sortedBy { it.name } }                          // ❌ stale if users changes
```

## What to Remember (and What Not To)

**Remember:** state, `MutableInteractionSource`, `FocusRequester`, expensive computations, `derivedStateOf`, `movableContentOf`, complex modifier chains.

**Do NOT remember:** `TextStyle`, `Dp`, `Alignment`, `RoundedCornerShape`, trivial immutable allocations — modifiers have their own caching.

## Recomposition Propagation

1. Recomposition starts at the **closest reader scope**.
2. Propagates to children unless they **skip** (stable inputs unchanged).
3. Inline layouts (`Row`, `Column`) share the caller's scope — reads inside them broaden invalidation.

## Narrow Reading Scope

Pass only what each child needs. Avoid a single large `UiState` everywhere.

```kotlin
ChatTopBar(loading = uiState.loading)           // ✅ narrow
ChatMessages(uiState)                           // ❌ input change invalidates everything
```

## Provider Lambdas `() -> T`

Defer reads to the child scope to limit recomposition. Use ONLY when measured performance proves benefit — adds lambda allocation and complexity.

## Backwards Writes — CRITICAL

Never write `MutableState` in the composable body. Causes infinite recomposition loop.

```kotlin
count++              // ❌ in body
onClick = { count++ }  // ✅ in event handler
```

## External Observables

| Source | Bridge |
|--------|--------|
| `StateFlow` / `Flow` | `collectAsStateWithLifecycle()` |
| `LiveData` | `observeAsState()` (legacy Android only) |
| RxJava | `subscribeAsState()` (legacy only) |

Never read `StateFlow.value` directly in composables — changes won't trigger recomposition.

## CompositionLocal

| Variant | On value change |
|---------|-----------------|
| `compositionLocalOf` | Only direct readers recompose |
| `staticCompositionLocalOf` | Entire subtree recomposes |

Reserve for cross-cutting framework values (theme, locale, density) — not general parameter passing.
