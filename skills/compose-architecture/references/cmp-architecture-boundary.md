# CMP Architecture Boundary

> **Discovery validated**: May 2026 — official JetBrains CMP docs for ViewModel and lifecycle.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

This reference documents the exact boundaries between Android-only and `commonMain`-safe architecture patterns. Apply these rules when migrating or building a shared architecture layer in Compose Multiplatform.

---

## 1. Lifecycle Artifact Version Gate

### collectAsStateWithLifecycle in commonMain

| Artifact | Version | commonMain | Notes |
|---------|---------|------------|-------|
| `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` | **2.10.0** | ✅ | Use for `viewModel { }` in CMP; JetBrains artifact |
| `androidx.lifecycle:lifecycle-runtime-compose` | **≥ 2.8.0** | ✅ | `collectAsStateWithLifecycle` available in commonMain |
| `androidx.lifecycle:lifecycle-runtime-compose` | **< 2.8.0** | ❌ | Must use `collectAsState()` or expect shim in commonMain |

### Fallback shim (pre-2.8 projects)

```kotlin
// commonMain/StateFlowExt.kt
expect fun <T> StateFlow<T>.collectAsStateLifecycleAware(): State<T>

// androidMain
actual fun <T> StateFlow<T>.collectAsStateLifecycleAware() =
    collectAsStateWithLifecycle()

// iosMain / desktopMain / wasmJsMain
actual fun <T> StateFlow<T>.collectAsStateLifecycleAware() =
    collectAsState()
```

---

## 2. ViewModel in commonMain

### Version gate: lifecycle-viewmodel-compose 2.10.0

With `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` **2.10.0**, `ViewModel` and `viewModel()` are available in `commonMain`.

```kotlin
// build.gradle.kts (shared module)
commonMain.dependencies {
    implementation("org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose:2.10.0")
}
```

**CRITICAL**: Always provide an initializer in `commonMain`. The parameterless `viewModel()` is not available in CMP commonMain:

```kotlin
// ✅ CORRECT — initializer provided
val vm = viewModel { MyViewModel() }

// ❌ WRONG in commonMain — will fail on non-JVM targets
val vm = viewModel<MyViewModel>()
```

### Desktop extra dependency

```kotlin
// jvmMain — required for coroutines on desktop
jvmMain.dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.8+")
}
```

### expect/actual ViewModel boundary (pre-2.10 projects)

For projects on older lifecycle versions, use a thin expect/actual wrapper:

```kotlin
// commonMain
expect abstract class PlatformViewModel() {
    protected val viewModelScope: CoroutineScope
    protected open fun onCleared()
}

// androidMain — delegate to real ViewModel
actual typealias PlatformViewModel = androidx.lifecycle.ViewModel

// iosMain / desktopMain
actual abstract class PlatformViewModel {
    protected actual val viewModelScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    protected actual open fun onCleared() {}
}
```

> Above lifecycle-viewmodel-compose 2.10.0, this boilerplate is unnecessary — use `ViewModel` directly in `commonMain`.

### Nav3 decorators in CMP (same as Android)

When using CMP Nav3 (`org.jetbrains.androidx.navigation3:navigation3-ui` 1.0.0-alpha05+), the same decorator pattern applies in `commonMain`:

```kotlin
NavDisplay(
    backStack = navBackStack,
    entryDecorator = rememberViewModelStoreNavEntryDecorator()
        then rememberSaveableStateHolderNavEntryDecorator(),
    entryProvider = entryProvider { ... }
)
```

---

## 3. DI Boundary

| Framework | Scope | Recommendation |
|-----------|-------|---------------|
| **Hilt** | `androidMain` ONLY | Default for Android. Cannot be used in `commonMain` (kapt, Java annotation processing). |
| **Koin** | `commonMain` ✅ | Preferred for CMP. Use `koin-compose-viewmodel` for `koinViewModel()`. |
| **Metro** | `commonMain` ✅ | Kotlin-first, CMP-compatible. |
| **Manual expect/actual** | `commonMain` ✅ | Zero-overhead, minimal abstraction. |

### Koin setup for CMP

```kotlin
// commonMain
val appModule = module {
    viewModel { MyViewModel(get()) }
}

@Composable
fun MyScreen() {
    val vm: MyViewModel = koinViewModel()
    // ...
}
```

### One-line guidance

> Inject in `androidMain` (Hilt), consume in `commonMain` via interface. For shared modules, use Koin or Metro.

---

## 4. State Collection per Platform

These patterns are all `commonMain`-safe — no changes needed for CMP:

```kotlin
// ✅ All multiplatform — no expect/actual needed
val uiState: StateFlow<UiState> = _uiState.asStateFlow()

val uiState = _uiState.stateIn(
    scope = viewModelScope,
    started = SharingStarted.WhileSubscribed(5_000),
    initialValue = UiState.Loading
)
```

- `MutableStateFlow` / `StateFlow` — fully multiplatform  
- `kotlinx.collections.immutable` (`ImmutableList<T>`) — multiplatform; no changes  
- `SharingStarted.WhileSubscribed(5_000)` — multiplatform  

---

## 5. viewModelScope and Coroutines

| API | commonMain (lifecycle ≥ 2.10) | commonMain (legacy) |
|-----|-------------------------------|---------------------|
| `viewModelScope` | ✅ multiplatform | ❌ Android-only → use expect scope |
| `Dispatchers.Main` | ✅ via `kotlinx-coroutines` | ✅ |
| `Dispatchers.IO` | ✅ via `kotlinx-coroutines` | ✅ |

### Legacy viewModelScope shim (pre-2.10)

```kotlin
// commonMain
expect val CoroutineScope.viewModelCoroutineScope: CoroutineScope

// androidMain
actual val CoroutineScope.viewModelCoroutineScope
    get() = (this as? androidx.lifecycle.ViewModel)?.viewModelScope ?: this

// iosMain / desktopMain
actual val CoroutineScope.viewModelCoroutineScope
    get() = CoroutineScope(SupervisorJob() + Dispatchers.Main)
```

---

## Validation

- **Validated**: 2026-05 (official JetBrains CMP ViewModel docs)
- **Target**: `org.jetbrains.androidx.lifecycle:lifecycle-viewmodel-compose` 2.10.0, CMP 1.10+
- **Review cadence**: Quarterly
