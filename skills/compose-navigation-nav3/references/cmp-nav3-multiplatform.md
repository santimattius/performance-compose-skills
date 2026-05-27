# CMP Nav3 — Multiplatform Setup

> **Discovery validated**: May 2026 — official JetBrains CMP Navigation 3 docs.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

Compose Multiplatform **1.10+** supports Nav3 on **Android, iOS, Desktop, and Web** via the JetBrains artifact `org.jetbrains.androidx.navigation3:navigation3-ui`.

---

## Artifact

| Artifact | Version | Platforms |
|---------|---------|-----------|
| `org.jetbrains.androidx.navigation3:navigation3-ui` | **1.0.0-alpha05** | Android · iOS · Desktop · Web |

> **Status (2026-05)**: Alpha. The `androidx.navigation3:navigation3-compose` artifact (Android-only) is the stable counterpart. For production CMP projects, evaluate stability before adopting.

```kotlin
// build.gradle.kts (shared module)
commonMain.dependencies {
    implementation("org.jetbrains.androidx.navigation3:navigation3-ui:1.0.0-alpha05")
    // Serialization is required on all targets
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7+")
}

plugins {
    kotlin("plugin.serialization")
}
```

---

## NavKey in CMP commonMain

On **non-JVM targets** (iOS, Web), `NavKey` serialization uses **kotlinx.serialization `SavedStateConfiguration`** — not reflection. Every `NavKey` must be `@Serializable`.

```kotlin
// commonMain — same API as Android Nav3
@Serializable
data object HomeKey : NavKey

@Serializable
data class ProductKey(val productId: String) : NavKey

// ❌ Not @Serializable → fails to restore state on non-JVM targets
data class BrokenKey(val id: String) : NavKey
```

---

## NavDisplay in commonMain

The API surface is identical to Android Nav3. Use the same decorator pattern:

```kotlin
@Composable
fun NavigationRoot() {
    val navBackStack = rememberNavBackStack(HomeKey)

    NavDisplay(
        backStack = navBackStack,
        entryDecorator = rememberViewModelStoreNavEntryDecorator()
            then rememberSaveableStateHolderNavEntryDecorator(),
        entryProvider = entryProvider {
            entry<HomeKey> { HomeScreen() }
            entry<ProductKey> { key -> ProductScreen(productId = key.productId) }
        }
    )
}
```

ViewModel integration requires `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` **2.10.0** — see [cmp-architecture-boundary.md](../compose-architecture/references/cmp-architecture-boundary.md).

---

## Android vs CMP artifact comparison

| Feature | `androidx.navigation3` (stable) | `org.jetbrains.androidx.navigation3` (alpha) |
|---------|--------------------------------|----------------------------------------------|
| Platforms | Android only | Android, iOS, Desktop, Web |
| Status | 1.0.0 stable | 1.0.0-alpha05 |
| NavKey serialization | `@Parcelize` + `@Serializable` | `@Serializable` + kotlinx.serialization SavedStateConfiguration |
| rememberNavBackStack | ✅ | ✅ |
| rememberViewModelStoreNavEntryDecorator | ✅ | ✅ (requires lifecycle-viewmodel-compose 2.10.0) |
| SceneStrategy (ListDetail, Dialog) | ✅ | ✅ |
| BottomSheetSceneStrategy | Copy from recipes | Copy from recipes |
| Deep links | ❌ (1.0.0) | ❌ (alpha) |

---

## Migration from Android-only to CMP Nav3

If you already use `androidx.navigation3` on Android and want to share navigation in `commonMain`:

1. Replace dependency `androidx.navigation3:navigation3-compose` → `org.jetbrains.androidx.navigation3:navigation3-ui`
2. Move `NavKey` declarations to `commonMain`
3. Remove `@Parcelize` (not needed on non-Android); keep `@Serializable`
4. Add `kotlin("plugin.serialization")` to the shared module
5. Move `NavDisplay` setup to `commonMain`

---

## When NOT to use CMP Nav3 (alpha)

For stable production-critical navigation on non-Android targets, prefer one of the alternatives in [cmp-alternatives.md](cmp-alternatives.md) (Decompose, Voyager) until CMP Nav3 reaches stable.

---

## Validation

- **Validated**: 2026-05 (official JetBrains CMP Navigation 3 docs)
- **Artifact**: `org.jetbrains.androidx.navigation3:navigation3-ui` 1.0.0-alpha05
- **CMP min version**: 1.10
- **Review cadence**: Quarterly — CMP Nav3 expected to stabilize during 2026
