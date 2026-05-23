# Nav3 Core API

## Building Blocks

| Component | Role |
|-----------|------|
| `NavKey` | Marker interface — every destination implements it |
| `NavBackStack` | Hoistable list/stack of keys — you own it |
| `NavDisplay` | Renders entry for current backstack state |
| `entryProvider` | Maps keys → composable entries |
| `SceneStrategy` | How entries render (single pane, list-detail, dialog overlay) |

## NavKey Requirements

```kotlin
@Serializable
data object HomeKey : NavKey

@Serializable
data class ProfileKey(val userId: String) : NavKey
```

Both `NavKey` AND `@Serializable` required for `rememberNavBackStack` process-death restore.

## Back Stack Creation

```kotlin
val navBackStack = rememberNavBackStack(HomeKey)  // ✅ auto save/restore

val manual = retain { mutableStateListOf<Any>() }           // ❌ no process death
val saveable = rememberSaveable { mutableStateListOf<Any>() } // ❌ no process death
```

Navigate: `navBackStack.add(key)`. Back: `navBackStack.removeLastOrNull()`.

## NavDisplay Minimum Setup

```kotlin
NavDisplay(
    backStack = navBackStack,
    entryDecorator = rememberViewModelStoreNavEntryDecorator(),  // REQUIRED for ViewModels
    entryProvider = entryProvider {
        entry<HomeKey> { HomeScreen(onNavigate = { navBackStack.add(DetailKey) }) }
        entry<DetailKey> { DetailScreen(onBack = navBackStack::removeLastOrNull) }
    },
)
```

## Entry Decorators — REQUIRED Patterns

| Decorator | Purpose |
|-----------|---------|
| `rememberViewModelStoreNavEntryDecorator()` | Clears ViewModel when entry popped — **prevents memory leak** |
| `rememberSaveableStateHolderNavEntryDecorator()` | Preserves `rememberSaveable` per entry across navigation |

Chain order: `saveableDecorator then vmStoreDecorator`

## entryProvider Rules

- Every key you `add()` MUST have matching `entry<Key> { }`
- Missing entry → `IllegalStateException`
- Empty backstack → `IllegalArgumentException`
- Generic type in `entry<T>` must match backstack key type

## SDK Requirements

```
compileSdk = 36
minSdk = 23
```

## Performance: ViewModel Scope

`rememberViewModelStoreNavEntryDecorator` prevents ViewModel re-creation on recomposition AND ensures cleanup on pop — without it, ViewModels accumulate for every visited destination.

## Arguments

Pass data as `NavKey` data class fields — no `SavedStateHandle` injection:

```kotlin
entry<ProfileKey> { key -> ProfileScreen(userId = key.userId) }
```

## Transitions

`NavDisplay` accepts `transitionSpec`, `popTransitionSpec`, `predictivePopTransitionSpec` for scene transitions.
