# Migration from Nav2

## API Mapping

| Nav2 | Nav3 |
|------|------|
| `rememberNavController()` | `rememberNavBackStack(initialKey)` |
| `NavHost { composable { } }` | `NavDisplay(entryProvider = { entry { } })` |
| `composable<Route> { }` | `entry<NavKey> { }` |
| `dialog<Route> { }` | `entry<Key>(metadata = DialogSceneStrategy.dialog())` |
| `navController.navigate(route)` | `navBackStack.add(key)` |
| `navController.popBackStack()` | `navBackStack.removeLastOrNull()` |
| `SavedStateHandle` args | `NavKey` data class fields |
| `navOptions { launchSingleTop }` | Manual: check + remove existing + add |

## Features NOT in Nav3 1.0.0

| Feature | Status |
|---------|--------|
| Deep links | ❌ Not supported |
| Nested nav graphs > 1 level | ❌ Not supported |
| Shared destinations across backstacks | ❌ Not supported |
| String route navigation | ❌ Use typed NavKey |
| `SavedStateHandle` injection | ❌ Use NavKey fields |

Evaluate migration blockers before adopting Nav3.

## Architectural Shift

Nav3 aligns with Compose best practices:
- Backstack IS hoistable state (not hidden inside NavController)
- Initial destination passed to backstack constructor (not NavHost parameter)
- Direct list mutation for navigation (explicit, testable)

## ViewModel Migration

Nav2: ViewModel scoped to back stack entry automatically in some setups.

Nav3: **Must** use `rememberViewModelStoreNavEntryDecorator()` — otherwise ViewModels never cleared on pop.

## Screen/Content Split with Nav3

Entry composables should follow same Screen/Content pattern — obtain ViewModel inside entry, pass state to Content. Do not pass ViewModel across entry boundaries.

## When to Stay on Nav2

- Deep link requirements
- Complex nested graphs
- Team not ready for compileSdk 36 / manual backstack management
