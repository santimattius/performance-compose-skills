# CMP Platform Rules — Canonical Reference

> Shared by every Compose skill in this repo. Linked from each `SKILL.md` via the `## CMP Applicability` section.
> **Discovery source**: Official JetBrains docs (May 2026) — Nav3 CMP, ViewModel CMP, iOS Accessibility, CMP UI Testing.

---

## 1. Source Set Map

Every CMP project uses a Kotlin Multiplatform source set hierarchy. Understand which set each API belongs to before using it.

| Source Set | Allowed Imports | Forbidden | Notes |
|------------|----------------|-----------|-------|
| `commonMain` | `androidx.compose.*`, `kotlinx.*`, `org.jetbrains.compose.*` | `android.*`, `platform.UIKit.*`, `java.awt.*`, `javax.swing.*`, `androidx.navigation3.*` (without CMP Nav3 setup) | Shared UI lives here |
| `androidMain` | All of `commonMain` + `android.*`, `androidx.*` | — | Full Android API surface |
| `iosMain` | All of `commonMain` + `platform.UIKit.*`, `platform.Foundation.*` | `android.*`, `java.awt.*` | iOS-specific platform code |
| `desktopMain` | All of `commonMain` + `java.awt.*`, `javax.swing.*` | `android.*`, `platform.UIKit.*` | JVM desktop |
| `wasmJsMain` / `jsMain` | All of `commonMain` + browser APIs | `android.*`, `java.awt.*`, `platform.UIKit.*` | Web targets |

### Quick rule: if the import starts with `android.` or `platform.UIKit.` it MUST live in `androidMain` or `iosMain`, never `commonMain`.

---

## 2. Forbidden Imports in commonMain

These imports in `commonMain` are always wrong. They will cause compilation failures or silent runtime errors on non-Android targets.

```
android.*
platform.UIKit.*
platform.Foundation.*         (use expect/actual instead)
java.awt.*
javax.swing.*
androidx.navigation3.*        (without org.jetbrains.androidx.navigation3 CMP artifact)
com.google.dagger.hilt.*      (kapt-only, Android-only)
```

**Audit recipe** (mirrors `compose-audit/references/cmp-considerations.md`):

```bash
rg -n '^import (android\.|platform\.UIKit|java\.awt\.|javax\.swing\.)' \
  --glob '**/src/commonMain/**' --type kotlin
```

Route to `CMP-PLATFORM-API-IN-COMMON` → `compose-architecture` boundary.

**Nav3 CMP boundary** (as of CMP 1.10 / alpha):

```bash
# Flag: androidx.navigation3 in commonMain WITHOUT the JetBrains CMP artifact
rg -n 'import androidx\.navigation3' --glob '**/src/commonMain/**' --type kotlin
```

Route to `CMP-NAV-COMMONMAIN` → `compose-navigation-nav3`.

---

## 3. expect / actual Patterns

Use `expect`/`actual` when platform code is unavoidable in a shared module.

### When to use expect/actual vs interface + factory

| Pattern | Use When |
|---------|----------|
| `expect`/`actual` | Thin platform shims: file I/O, platform logging, single function |
| Interface + factory | Complex platform services with multiple methods; testable |

### Naming conventions

```kotlin
// commonMain/Platform.kt — suffix Platform for clarity
expect fun getPlatformName(): String
expect class PlatformContext

// androidMain/Platform.android.kt
actual fun getPlatformName(): String = "Android"
actual class PlatformContext(val context: android.content.Context)

// iosMain/Platform.ios.kt
actual fun getPlatformName(): String = "iOS"
actual class PlatformContext
```

**Audit recipe**:

```bash
rg -n '^expect (fun|class|object|val)' --glob '**/src/commonMain/**' --type kotlin
```

For each `expect`, verify `actual` exists in at least one target source set. Missing actual → `CMP-EXPECT-NO-ACTUAL`.

---

## 4. Lifecycle & State Collection

### Version gate: collectAsStateWithLifecycle in commonMain

| Artifact | Version | commonMain availability |
|----------|---------|------------------------|
| `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` | **2.10.0** | `viewModel { MyViewModel() }` in commonMain ✅ |
| `androidx.lifecycle:lifecycle-runtime-compose` | **2.8+** | `collectAsStateWithLifecycle` in commonMain ✅ |
| `androidx.lifecycle:lifecycle-runtime-compose` | **< 2.8** | commonMain MUST use `collectAsState()` |

> **IMPORTANT (2026-05 update)**: Use `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` **2.10.0** for CMP ViewModel support. The `viewModel()` composable in commonMain MUST always provide an initializer: `viewModel { MyViewModel() }` — never use the parameterless form.

### collectAsStateWithLifecycle availability by target (lifecycle ≥ 2.8)

| Target | Available | Notes |
|--------|-----------|-------|
| Android | ✅ | Full lifecycle awareness |
| iOS | ✅ | Via multiplatform lifecycle artifact |
| Desktop (JVM) | ✅ | Requires `kotlinx-coroutines-swing` in `jvmMain` |
| Web (wasmJs) | ✅ | Via multiplatform lifecycle artifact |

### Fallback when below lifecycle 2.8

```kotlin
// commonMain — fallback shim
expect fun <T> StateFlow<T>.collectAsStateLifecycleAware(): State<T>

// androidMain
actual fun <T> StateFlow<T>.collectAsStateLifecycleAware() =
    collectAsStateWithLifecycle()

// iosMain / desktopMain / wasmJsMain
actual fun <T> StateFlow<T>.collectAsStateLifecycleAware() =
    collectAsState()
```

Cross-link → [compose-architecture/references/cmp-architecture-boundary.md](../compose-architecture/references/cmp-architecture-boundary.md)

---

## 5. Dependency Injection Across Platforms

| DI Framework | Scope | Notes |
|-------------|-------|-------|
| **Hilt** | `androidMain` ONLY | Requires kapt, `dagger.hilt.android`; cannot be used in commonMain |
| **Koin** | `commonMain` ✅ | Preferred for CMP shared modules; `koin-compose-viewmodel` for `koinViewModel()` |
| **Metro** | `commonMain` ✅ | Kotlin-first DI; CMP-compatible |
| **Manual expect/actual factory** | `commonMain` ✅ | Minimal abstraction, zero runtime overhead |

### expect factory pattern (3-line sketch)

```kotlin
// commonMain
expect fun createRepository(): Repository

// androidMain
actual fun createRepository(): Repository = AndroidRepository(/*Hilt injected deps*/)

// iosMain
actual fun createRepository(): Repository = IosRepository()
```

### Guidance: inject in androidMain, consume in commonMain via interface

Cross-link → [compose-architecture/references/cmp-architecture-boundary.md](../compose-architecture/references/cmp-architecture-boundary.md)

---

## 6. Navigation Across Platforms

### Nav3 in CMP (CMP 1.10+ / alpha)

> **Discovery update (2026-05)**: Compose Multiplatform **1.10+** adds CMP Nav3 support.

| Artifact | Version | Platforms |
|---------|---------|-----------|
| `org.jetbrains.androidx.navigation3:navigation3-ui` | **1.0.0-alpha05** | Android, iOS, Desktop, Web |

**Non-JVM serialization note**: On non-JVM targets, `NavKey` serialization uses **kotlinx.serialization `SavedStateConfiguration`** (not reflection). Add the plugin:

```kotlin
// build.gradle.kts (shared module)
plugins {
    kotlin("plugin.serialization")
}
```

**CMP Nav3 `NavDisplay` setup** (same decorator pattern as Android):

```kotlin
// commonMain — same API as Android Nav3
NavDisplay(
    backStack = navBackStack,
    entryDecorator = rememberViewModelStoreNavEntryDecorator()
        then rememberSaveableStateHolderNavEntryDecorator(),
    entryProvider = entryProvider { ... }
)
```

### Android-only Nav3 (`androidx.navigation3`)

The `androidx.navigation3:navigation3-compose` artifact is **Android-only**. Do NOT use it in `commonMain`; use `org.jetbrains.androidx.navigation3:navigation3-ui` for CMP.

| Audit pattern | Route |
|--------------|-------|
| `CMP-NAV-COMMONMAIN` | `compose-navigation-nav3` (redirects to CMP setup) |

### CMP navigation alternatives (when CMP Nav3 alpha is too early)

| Library | Process-death safety | Multi-platform | Notes |
|---------|---------------------|----------------|-------|
| CMP Nav3 (alpha) | ✅ | Android, iOS, Desktop, Web | `org.jetbrains.androidx.navigation3:navigation3-ui` 1.0.0-alpha05 |
| Decompose | ✅ | All targets | Production-ready; more verbose API |
| Voyager | ✅ | Android, iOS, Desktop, Web | Simpler API; less community support |
| compose-router | ✅ | All targets | Compose-idiomatic; newer project |
| Plain back-stack | Manual | All targets | Full control; no process-death by default |

Cross-link → [compose-navigation-nav3/references/cmp-nav3-multiplatform.md](../compose-navigation-nav3/references/cmp-nav3-multiplatform.md) · [compose-navigation-nav3/references/cmp-alternatives.md](../compose-navigation-nav3/references/cmp-alternatives.md)

---

## 7. View Interop Across Platforms

| Platform | Mechanism | Skill |
|---------|-----------|-------|
| **Android** | `AndroidView`, `ComposeView`, `ViewCompositionStrategy` | `compose-views-interop` (full coverage) |
| **iOS** | `UIKitView`, `UIKitViewController`, `ComposeUIViewController` | Out of scope — see below |
| **Desktop** | `SwingPanel`, `SwingInterop` | Out of scope |
| **Web** | `HtmlView` (experimental) | Out of scope |

**iOS interop basics** (`iosMain`):

```kotlin
UIKitView(
    factory = { UILabel() },
    update = { label -> label.text = "Hello from UIKit" }
)
```

`compose-views-interop` covers **Android only**. For iOS/Desktop/Web interop, refer to official JetBrains CMP documentation.

---

## 8. Tooling Availability Matrix

| Tool | Android | iOS | Desktop | Web | Notes |
|------|---------|-----|---------|-----|-------|
| Android Studio `@Preview` | ✅ | ❌ | ❌ | ❌ | AGP-integrated |
| JetBrains `@Preview` (Fleet / IJ) | ✅ | ✅ | ✅ | ✅ | CMP 1.5+; `org.jetbrains.compose.ui.tooling` |
| Compose Hot Reload | ✅ | ✅ | ✅ | ✅ | JetBrains plugin; experimental |
| Layout Inspector | ✅ | ❌ | ❌ | ❌ | Android Studio only |
| Paparazzi | ✅ | ❌ | ❌ | ❌ | JVM/Android renderer |
| Roborazzi | ✅ | ⚠️ | ⚠️ | ❌ | 1.7+; iOS/Desktop via JVM runner with caveats |
| Macrobenchmark | ✅ | ❌ | ❌ | ❌ | Android profiling infra |
| `runComposeUiTest` | ✅ | ✅ | ✅ | ✅ | `org.jetbrains.compose.ui:ui-test`; commonTest |
| `compose-ui-test-junit4` | ✅ | ❌ | ❌ | ❌ | Android JUnit4 rule only |
| iOS Instruments | ❌ | ✅ | ❌ | ❌ | Native iOS profiling |
| JFR / JVisualVM | ❌ | ❌ | ✅ | ❌ | JVM desktop profiling |
| Chrome DevTools | ❌ | ❌ | ❌ | ✅ | wasm/JS profiling |

Cross-link → [compose-previews-tooling/references/cmp-tooling-matrix.md](../compose-previews-tooling/references/cmp-tooling-matrix.md)

---

## 9. Per-Skill CMP Applicability Index

Quick lookup: skill → worst-case `commonMain` status.

| Skill | commonMain | Key Android-Only Items | Detailed Reference |
|-------|------------|------------------------|-------------------|
| `compose-composition-core` | ✅ | None — `remember { Context }` = platform leak | [SKILL.md](../compose-composition-core/SKILL.md) |
| `compose-modifier-system` | ✅ | None — `graphicsLayer`, `drawBehind`, `Modifier.Node` all safe | [SKILL.md](../compose-modifier-system/SKILL.md) |
| `compose-effects` | ⚠️ | `collectAsStateWithLifecycle` needs lifecycle ≥ 2.8 | [SKILL.md](../compose-effects/SKILL.md) |
| `compose-animations` | ✅ | None — all animation APIs are commonMain-safe | [SKILL.md](../compose-animations/SKILL.md) |
| `compose-architecture` | ⚠️ | Hilt = androidMain; ViewModel 2.10+; lifecycle 2.8+ gate | [cmp-architecture-boundary.md](../compose-architecture/references/cmp-architecture-boundary.md) |
| `compose-navigation-nav3` | ⚠️ | CMP Nav3 alpha (1.0.0-alpha05) since CMP 1.10; use `org.jetbrains.androidx.navigation3` | [cmp-nav3-multiplatform.md](../compose-navigation-nav3/references/cmp-nav3-multiplatform.md) |
| `compose-previews-tooling` | ⚠️ | Paparazzi/Macrobenchmark/Layout Inspector = Android only | [cmp-tooling-matrix.md](../compose-previews-tooling/references/cmp-tooling-matrix.md) |
| `compose-quality` | ⚠️ | Semantics/a11y ✅; Paparazzi = Android only; iOS: VoiceOver + AccessibilitySyncOptions | [cmp-ios-accessibility.md](../compose-quality/references/cmp-ios-accessibility.md) |
| `compose-views-interop` | ❌ | Entire skill is Android-only (`android.view.View`) | [SKILL.md](../compose-views-interop/SKILL.md) |

---

## 10. Version Pinning & Re-validation

### Validated versions (2026-05)

| API / Artifact | Min CMP Version | Min Artifact Version | Notes |
|---------------|----------------|---------------------|-------|
| `collectAsStateWithLifecycle` in commonMain | CMP 1.6+ | `lifecycle-runtime-compose` 2.8+ | |
| JetBrains `@Preview` | CMP 1.5+ | `compose.ui.tooling` any | |
| Roborazzi in CMP | CMP 1.6+ | `roborazzi` 1.7+ | Android runner only |
| CMP Nav3 | CMP 1.10+ | `navigation3-ui` 1.0.0-alpha05 | `org.jetbrains.androidx.navigation3` |
| `viewModel { }` in commonMain | CMP 1.10+ | `lifecycle-viewmodel-compose` 2.10.0 | Use `org.jetbrains.androidx.lifecycle` |
| `runComposeUiTest` | CMP 1.5+ | `ui-test` any | `org.jetbrains.compose.ui:ui-test` |
| Compose Hot Reload | CMP 1.6+ | Hot Reload plugin | Experimental |

### context7 MCP re-validation commands

```bash
# Validate lifecycle-viewmodel-compose multiplatform availability
mcp context7 resolve-library-id --library "jetbrains/compose-multiplatform"
mcp context7 get-library-docs --libraryId <id> --topic "lifecycle viewmodel"

# Validate Nav3 CMP status
mcp context7 resolve-library-id --library "androidx/navigation3"
mcp context7 get-library-docs --libraryId <id> --topic "multiplatform CMP"

# Validate Roborazzi CMP support
mcp context7 resolve-library-id --library "takahirom/roborazzi"
```

**Review cadence**: Quarterly or when a new CMP major version ships.
