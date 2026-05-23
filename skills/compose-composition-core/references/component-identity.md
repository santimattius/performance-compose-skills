# Component Identity

Compose identifies composable calls by **position in the UI tree** (path of call-site IDs). Identity determines whether `remember` state is kept, reinitialized, or disposed.

## Three Outcomes on Recomposition

| Situation | Result |
|-----------|--------|
| Same call-site ID as before | **Recompose** — state preserved |
| New call-site ID | **Compose** — state initialized fresh |
| Previous call-site no longer called | **Dispose** — state lost |

## Conditional Calls vs Conditional Arguments

```kotlin
// ❌ Different call-site IDs — state resets on branch switch
if (premium) PremiumContent() else FreeContent()

// ✅ Same call-site ID — state preserved, only args change
Content(isPremium = premium)
```

## Loop Identity — Default Is Index

```kotlin
items.forEach { item -> ItemRow(item) }  // identity = index → breaks on insert/remove/reorder
```

Insert at top shifts all indices → every item below gets new identity → state bugs and wasted work.

## Keys

Wrap calls with `key(stableId) { ... }` or use LazyList `key` parameter.

```kotlin
LazyColumn {
    items(items, key = { it.id }) { item -> ItemRow(item) }  // ✅
}

LazyColumn {
    items(items) { item ->
        key(item.id) { ItemRow(item) }  // ❌ wrong — key inside item lambda doesn't work
    }
}
```

### Good Key Properties

- Unique among siblings
- Stable for the same logical item over time
- Android: storable in `Bundle` (`String`, `Int`, etc.)
- Avoid whole-object keys — any field change resets identity

## Local State + Lists — Dangerous

```kotlin
LazyColumn {
    items(todos) { todo ->
        var done by remember { mutableStateOf(false) }  // ❌ without key, done follows index not todo
        TodoRow(todo, done, onDoneChange = { done = it })
    }
}
```

**Fix:** add `key = { it.id }` AND hoist meaningful state to ViewModel.

## ViewModel Scope Reset

When same composable type appears consecutively with different data, use `key(stepId)` to force fresh ViewModel/state:

```kotlin
key(step.number) {
    SingleAnswerStepView(step = step, stepKey = step.number)
}
```

## `movableContentOf`

Preserves identity when reparenting content (e.g., Row ↔ Column switch) without losing `remember` state.

```kotlin
val content = remember {
    movableContentOf { CounterCard() }
}
if (horizontal) Row { content() } else Column { content() }
```

Use for: layout switches, shared element transitions, dynamic reparenting. Not for general performance optimization.
