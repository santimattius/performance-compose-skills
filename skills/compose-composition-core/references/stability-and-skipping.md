# Stability and Strong Skipping Mode

## Three Type Categories

| Category | Examples | Safe to pass down? |
|----------|----------|-------------------|
| **Immutable** | `String`, `Int`, `Boolean`, `PersistentList` | Always |
| **Stable** | `State<T>`, function types, state holders (`LazyListState`, `@Stable` classes) | Yes — changes are observable |
| **Unstable** | `MutableList`, ViewModels, classes with `var` or unstable properties | Avoid — pass stable/immutable data instead |

## Strong Skipping Mode (default since Kotlin 2.0.20)

Changes how Compose compares arguments during skip decisions:

| Type | Comparison |
|------|------------|
| Stable / immutable | `==` (structural equality) |
| Unstable | `===` (reference equality) |

Applies to: composable parameters, `remember` keys, effect keys.

**Also introduces:** automatic lambda memoization — all lambdas in composables wrapped in `remember(capturedVars) { { ... } }`. Opt out with `@DontMemoize`.

> Debug builds disable Strong Skipping — profile release/benchmark builds only.

## Collections

`List`, `Set`, `Map` are unstable (mutable implementations exist). Use `PersistentList`/`PersistentSet`/`PersistentMap` from `kotlinx.collections.immutable`.

**Stability config** (if collections are never mutated after passing):

```
composeCompiler {
    stabilityConfigurationFiles = listOf(rootProject.layout.projectDirectory.file("stability_config.conf"))
}
```

```
kotlin.collections.List
kotlin.collections.Set
kotlin.collections.Map
```

## Enforcing Stability

- `@Immutable` — class never changes (all `val`, all stable types)
- `@Stable` — may be mutable but contractually stable (e.g., backed by snapshot state)
- `@Stable` on interfaces — required; all implementations must honor it

## Compiler Reports

```kotlin
composeCompiler {
    reportsDestination = layout.buildDirectory.dir("compose_compiler")
}
```

Look for `restartable skippable` (good) vs `unstable` parameters (investigate).

## Common Unstable Chain

```
unstable class ScreenUiState { unstable val user: User? }
unstable class User { unstable val tags: List<String> }
```

Fix: `List<String>` → `PersistentList<String>` makes both stable.

## Passing State Objects

```kotlin
fun UserItem(user: User)                    // ✅ pass value
fun UserItem(userProvider: () -> User)      // ✅ defer read
fun UserItem(userState: State<User>)        // ❌ exposes storage mechanism
```

## Skip Decision Summary

Composable skips recomposition when ALL parameters are unchanged per their stability comparison rules. One unstable parameter compared by reference can force recomposition even if contents are equal.
