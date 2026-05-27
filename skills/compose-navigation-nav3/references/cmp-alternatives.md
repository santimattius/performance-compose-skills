# CMP Navigation Alternatives

> For CMP projects not yet ready for `org.jetbrains.androidx.navigation3` alpha, or needing stable navigation on all targets.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

**Context**: `androidx.navigation3:navigation3-compose` (Android stable 1.0.0) is Android-only. For Compose Multiplatform sharing navigation across platforms, use CMP Nav3 (alpha) or one of the alternatives below.

> **This repo does NOT teach these libraries** — we only document the trade-offs so you can make an informed choice. For production usage, consult each library's official documentation.

---

## Comparison Table

| Library | Process-death safety | Platforms | Multi-pane | Learning curve | Status |
|---------|---------------------|-----------|-----------|----------------|--------|
| **CMP Nav3** (`org.jetbrains.androidx.navigation3`) | ✅ (`rememberNavBackStack`) | Android · iOS · Desktop · Web | ✅ (SceneStrategy) | Low (Nav3 API) | 1.0.0-alpha05 |
| **Decompose** | ✅ (StateKeeper) | All KMP targets | ✅ | High | Stable |
| **Voyager** | ✅ | Android · iOS · Desktop · Web | ⚠️ Limited | Low | Stable |
| **compose-router** | ✅ | All KMP targets | ⚠️ In progress | Low | Beta |
| **Plain back-stack** | Manual | All targets | Manual | Low (but bespoke) | N/A |

---

## CMP Nav3 (recommended when alpha is acceptable)

```kotlin
// commonMain — same API as Android Nav3
// Artifact: org.jetbrains.androidx.navigation3:navigation3-ui:1.0.0-alpha05
@Serializable data object HomeKey : NavKey

NavDisplay(
    backStack = rememberNavBackStack(HomeKey),
    entryDecorator = rememberViewModelStoreNavEntryDecorator(),
    entryProvider = entryProvider { entry<HomeKey> { HomeScreen() } }
)
```

See full setup: [cmp-nav3-multiplatform.md](cmp-nav3-multiplatform.md)

---

## Decompose

Strong community track record. State-machine-based navigation with built-in process-death support via `StateKeeper`.

```kotlin
// commonMain — sketch only
interface RootComponent {
    val childStack: Value<ChildStack<*, Child>>
    sealed class Child { class Home(val component: HomeComponent) : Child() }
}
```

Official docs: [arkivanov.github.io/Decompose](https://arkivanov.github.io/Decompose/)

---

## Voyager

Simple API, close to Nav3 mental model. Less active maintenance than Decompose.

```kotlin
// commonMain — sketch only
Navigator(screen = HomeScreen()) { navigator ->
    CurrentScreen()
}
```

Official docs: [voyager.adriel.cafe](https://voyager.adriel.cafe/)

---

## compose-router

Compose-idiomatic router designed for KMP. Newer project; growing community.

Official docs: [github.com/xxfast/KRouter](https://github.com/xxfast/KRouter) (or the compose-router equivalent)

---

## Plain Back-Stack with expect/actual

Use when you want a Nav3-shaped API in `commonMain` but delegate to Decompose (or any library) on specific platforms. This is the thinnest possible abstraction:

```kotlin
// commonMain — minimal NavBackStack expect stub
expect class NavBackStack<Key : Any>(initial: Key) {
    val stack: List<Key>
    fun push(key: Key)
    fun pop(): Key?
}

// androidMain — delegate to rememberNavBackStack or Decompose
actual class NavBackStack<Key : Any>(initial: Key) {
    actual val stack = mutableStateListOf(initial)
    actual fun push(key: Key) { stack.add(key) }
    actual fun pop() = if (stack.size > 1) stack.removeLast() else null
}

// iosMain / desktopMain — same or delegate to Decompose StateKeeper
actual class NavBackStack<Key : Any>(initial: Key) { /* ... */ }
```

> This approach gives you process-death safety on Android (pair with `rememberSaveable`) at the cost of no cross-platform serialization out of the box.

---

## Decision guide

```
Need stable nav today on all targets?
  → Decompose (production-tested) or Voyager (simpler API)

Comfortable with alpha?
  → CMP Nav3 — same API as Android Nav3, easiest migration path

Want Nav3 API on Android, anything on other platforms?
  → Plain back-stack expect/actual stub (above) delegating per platform

Already using Hilt + Decompose on Android?
  → Keep Decompose; do not adopt CMP Nav3 until stable
```
