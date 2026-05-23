---
name: compose-navigation-nav3
description: >
  Jetpack Compose Navigation 3 (Nav3 1.0.0 stable): NavKey, NavDisplay, NavBackStack,
  SceneStrategy, ViewModel decorators, process-death safety, and Nav2→Nav3 migration.
  Trigger: when implementing navigation in Compose with Nav3, migrating from Nav2,
  using NavKey, NavDisplay, SceneStrategy, bottom sheet/dialog navigation, or wiring
  ViewModels to navigation entries.
license: Apache-2.0
metadata:
  author: Santiago Mattiauda
  version: "1.0"
---

> **VALIDATED 2026-05 · Nav3 1.0.0 (stable)**

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

### ViewModelStoreDecorator — Preventing ViewModel Re-creation on Navigation

```kotlin
// ✅ With rememberViewModelStoreNavEntryDecorator — ViewModels survive back-stack pops
@Composable
fun NavigationRoot() {
    val navBackStack = rememberNavBackStack(HomeKey)
    val vmStoreDecorator = rememberViewModelStoreNavEntryDecorator()

    NavDisplay(
        backStack = navBackStack,
        entryDecorator = vmStoreDecorator,   // ← prevents ViewModel re-creation per entry
        entryProvider = entryProvider { ... }
    )
}

// ❌ Without decorator — every navigation pop destroys and recreates the ViewModel
// This causes: unnecessary composition cost + memory churn + state loss
NavDisplay(
    backStack = navBackStack,
    entryProvider = entryProvider { ... }  // no decorator = no ViewModel scope management
)
```

Each nav entry without `rememberViewModelStoreNavEntryDecorator` creates a fresh ViewModel on
every push and leaks the old one on pop (never cleared). Compose cost: full recomposition of
the entry as state initializes from scratch.

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
- Implementing navigation in a new Compose app
- Migrating from Nav2 (`NavController`, `NavHost`) to Nav3 (`NavDisplay`, `NavBackStack`)
- Setting up multi-pane navigation (list-detail, tablet layouts)
- Wiring ViewModels to navigation entries safely
- Adding dialogs or bottom sheets as navigation destinations
- Handling process death and back-stack state restoration

---

## When to Use This vs compose-architecture

`compose-architecture` covers ViewModel scoping, `collectAsStateWithLifecycle`, and the Screen/Content split. `compose-navigation-nav3` covers how entries are structured, how the back stack is managed, and how ViewModel lifecycle is tied to navigation entries via decorators. Use both when connecting ViewModels to specific nav destinations.

---

## Critical Patterns

### 1. NavKey — Every Route MUST Implement This Interface

`NavKey` is a marker interface. Every destination MUST implement it AND be `@Serializable` so `rememberNavBackStack` can persist and restore the back stack across process death.

```kotlin
// ✅ Object destination (no arguments)
@Serializable
data object HomeKey : NavKey

// ✅ Data class destination (with arguments)
@Serializable
data class UserProfileKey(val userId: String) : NavKey

// ❌ Missing @Serializable — rememberNavBackStack cannot restore state after process death
data class BrokenKey(val id: String) : NavKey
```

### 2. `rememberNavBackStack` — REQUIRED for Process-Death Save/Restore

Use `rememberNavBackStack` to create the back stack. It automatically serializes and restores navigation state. Alternatives do NOT survive process death.

```kotlin
// ✅ Survives process death automatically
val navBackStack = rememberNavBackStack(HomeKey)

// ❌ Does NOT survive process death — state lost on system kill
val manualBackStack = retain { mutableStateListOf<Any>() }
val saveableBackStack = rememberSaveable { mutableStateListOf<Any>() }
```

### 3. `rememberViewModelStoreNavEntryDecorator` — REQUIRED, Not Optional

Without this decorator, ViewModels associated with navigation entries are NEVER cleared when the entry is popped from the back stack. This is a guaranteed memory leak in any app using ViewModels with Nav3.

```kotlin
@Composable
fun NavigationRoot() {
    val navBackStack = rememberNavBackStack(HomeKey)

    // REQUIRED — must be created before NavDisplay
    val vmStoreDecorator = rememberViewModelStoreNavEntryDecorator()

    NavDisplay(
        backStack = navBackStack,
        entryDecorator = vmStoreDecorator,
        entryProvider = entryProvider {
            entry<HomeKey> { HomeScreen() }
        }
    )
}
```

### 4. `rememberSaveableStateHolderNavEntryDecorator` — Per-Entry UI State

Preserves `rememberSaveable` state per entry as users navigate. Without it, UI state (scroll position, text input, etc.) is reset every time the entry is re-entered.

```kotlin
val saveableDecorator = rememberSaveableStateHolderNavEntryDecorator()
val vmStoreDecorator = rememberViewModelStoreNavEntryDecorator()

NavDisplay(
    backStack = navBackStack,
    // Chain decorators — order matters: saveable wraps vm store
    entryDecorator = saveableDecorator then vmStoreDecorator,
    entryProvider = entryProvider { ... }
)
```

### 5. BottomSheetSceneStrategy — NOT in Core Artifact

There is NO built-in `BottomSheetSceneStrategy` in the Nav3 core library. You MUST copy the implementation from the Nav3 recipes/samples or write it yourself. The core only ships `SinglePaneSceneStrategy`, `ListDetailSceneStrategy`, and `DialogSceneStrategy`.

```kotlin
// ✅ What IS in core:
sceneStrategy = SinglePaneSceneStrategy()          // default
sceneStrategy = rememberListDetailSceneStrategy()  // list-detail
val dialogStrategy = remember { DialogSceneStrategy<NavKey>() }

// ❌ What is NOT in core — must copy from recipes:
// BottomSheetSceneStrategy — copy from Nav3 sample/recipes repo

// Custom BottomSheet scene strategy usage (after copying implementation):
val bottomSheetStrategy = remember { BottomSheetSceneStrategy<NavKey>() }
NavDisplay(
    backStack = navBackStack,
    sceneStrategy = rememberListDetailSceneStrategy() then bottomSheetStrategy,
    entryProvider = entryProvider {
        entry<BottomSheetKey>(
            metadata = BottomSheetSceneStrategy.bottomSheet()
        ) {
            MyBottomSheetContent(onDismiss = navBackStack::removeLastOrNull)
        }
    }
)
```

### 6. Minimum Requirements

```
compileSdk = 36
minSdk = 23
```

Confirm in `build.gradle.kts` before enabling Nav3. Using a lower `compileSdk` will cause compilation errors on Nav3 APIs.

### 7. Nav2 Features NOT Supported in Nav3

| Feature | Nav2 | Nav3 Status |
|---------|------|-------------|
| Deep links | ✅ Supported | ❌ Not supported in 1.0.0 |
| Nested nav graphs > 1 level | ✅ Supported | ❌ Not supported |
| Shared destinations across backstacks | ✅ Possible | ❌ Not supported |
| `NavController.navigate(route: String)` | ✅ Supported | ❌ Replaced by back-stack mutation |
| `SavedStateHandle` argument injection | ✅ Supported | ❌ Use NavKey data class fields instead |

### 8. Nav2 → Nav3 API Mapping Table

| Nav2 | Nav3 | Notes |
|------|------|-------|
| `rememberNavController()` | `rememberNavBackStack(initial)` | The backstack IS the controller |
| `NavHost { }` | `NavDisplay(entryProvider = { })` | `NavDisplay` observes the backstack |
| `composable<Key> { }` | `entry<Key> { }` | Inside `entryProvider { }` |
| `dialog<Key> { }` | `entry<Key>(metadata = DialogSceneStrategy.dialog())` | Needs `DialogSceneStrategy` registered |
| `navController.navigate(key)` | `navBackStack.add(key)` | Direct list mutation |
| `navController.popBackStack()` | `navBackStack.removeLastOrNull()` | Direct list mutation |
| Arguments via `SavedStateHandle` | Arguments as `NavKey` data class fields | `entry<UserKey> { key -> key.userId }` |
| `navOptions { launchSingleTop = true }` | Manual: remove existing + add | No built-in equivalents |

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| Missing `@Serializable` on NavKey | Add `@Serializable` + kotlinx.serialization plugin | Process death = navigation state lost |
| No `rememberViewModelStoreNavEntryDecorator` | Add decorator to `entryDecorator` param | ViewModel memory leak on every pop |
| Using `mutableStateListOf` as backstack | Use `rememberNavBackStack` | No process-death save/restore |
| Passing a ViewModel to an entry's content composable | Pass state + lambdas only | Couples nav entry to ViewModel, breaks Screen/Content split |
| Empty backstack passed to NavDisplay | Always initialize with at least one key | `IllegalArgumentException` at runtime |
| Navigating to undeclared entry key | Ensure all keys have a matching `entry<Key>` | `IllegalStateException` at runtime |
| Using `BottomSheetSceneStrategy` without copying implementation | Copy from Nav3 recipes — it is not in `androidx.navigation3` | Compile error |

---

## Code Examples

### Minimal Nav3 Setup

```kotlin
@Serializable data object HomeKey : NavKey
@Serializable data object DetailKey : NavKey

@Composable
fun NavigationRoot() {
    val navBackStack = rememberNavBackStack(HomeKey)
    val vmStoreDecorator = rememberViewModelStoreNavEntryDecorator()

    NavDisplay(
        backStack = navBackStack,
        entryDecorator = vmStoreDecorator,
        entryProvider = entryProvider {
            entry<HomeKey> {
                HomeScreen(
                    onNavigateToDetail = { navBackStack.add(DetailKey) }
                )
            }
            entry<DetailKey> {
                DetailScreen(
                    onNavigateBack = { navBackStack.removeLastOrNull() }
                )
            }
        },
        transitionSpec = {
            slideInHorizontally(initialOffsetX = { it }) togetherWith scaleOut(targetScale = .9f)
        },
        popTransitionSpec = {
            scaleIn(initialScale = .9f) togetherWith slideOutHorizontally(targetOffsetX = { it })
        }
    )
}
```

### Passing Arguments

```kotlin
@Serializable
data class ProductKey(val productId: String) : NavKey

entryProvider = entryProvider {
    entry<ProductKey> { key ->
        // key is the actual ProductKey instance — no parsing needed
        ProductScreen(productId = key.productId)
    }
}
```

### List-Detail Layout

```kotlin
@OptIn(ExperimentalMaterial3AdaptiveApi::class)
NavDisplay(
    backStack = navBackStack,
    entryDecorator = rememberViewModelStoreNavEntryDecorator(),
    sceneStrategy = rememberListDetailSceneStrategy(),
    entryProvider = entryProvider {
        entry<ListKey>(
            metadata = ListDetailSceneStrategy.listPane(detailPlaceholder = { EmptyDetail() })
        ) {
            ListScreen(onItemSelected = { id -> navBackStack.add(DetailKey(id)) })
        }
        entry<DetailKey>(
            metadata = ListDetailSceneStrategy.detailPane()
        ) { key ->
            DetailScreen(id = key.id)
        }
    }
)
```

---

## Commands

```bash
# Add Nav3 to your project (libs.versions.toml)
# [versions]
# navigation3 = "1.0.0"
# [libraries]
# androidx-navigation3-compose = { group = "androidx.navigation3", name = "navigation3-compose", version.ref = "navigation3" }

# Verify compileSdk and minSdk in build.gradle.kts:
# android {
#     compileSdk = 36
#     defaultConfig { minSdk = 23 }
# }
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-architecture` | `../compose-architecture/SKILL.md` | ViewModel scoping, Screen/Content split, collectAsStateWithLifecycle |
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Recomposition rules that affect nav entry rendering cost |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/nav3-core-api.md](references/nav3-core-api.md) | NavKey, NavBackStack, NavDisplay, decorators |
| [references/scene-strategies.md](references/scene-strategies.md) | Dialog, ListDetail, BottomSheet (custom) |
| [references/migration-from-nav2.md](references/migration-from-nav2.md) | Nav2→Nav3 mapping, unsupported features |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx, compileSdk 36, minSdk 23
- **Stable APIs**: Nav3 1.0.0 — `NavKey`, `NavDisplay`, `rememberNavBackStack`, `NavBackStack`, `entryProvider`, `SinglePaneSceneStrategy`, `ListDetailSceneStrategy`, `DialogSceneStrategy`
- **Experimental/Alpha**: `rememberListDetailSceneStrategy` — `@ExperimentalMaterial3AdaptiveApi` as of 2026-05
- **Not in core**: `BottomSheetSceneStrategy` — copy from Nav3 recipes/samples
- **Unsupported (Nav3 1.0.0)**: Deep links, nested nav graphs > 1 level, shared destinations across backstacks
- **SDK requirements**: `compileSdk = 36`, `minSdk = 23`
- **Review cadence**: Quarterly
