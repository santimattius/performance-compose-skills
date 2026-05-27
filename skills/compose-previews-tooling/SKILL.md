---
name: compose-previews-tooling
description: >
  Jetpack Compose previews, tooling, and performance profiling: @Preview, @PreviewWrapper,
  @PreviewParameter, screenshot testing, Compose Compiler Reports, Composition Tracing,
  Layout Inspector, and Macrobenchmark. Trigger: when working with @Preview, @PreviewWrapper,
  @PreviewParameter, screenshot testing, Paparazzi, Roborazzi, Baseline Profiles,
  Compose Compiler Reports, Layout Inspector, Composition Tracing, or Macrobenchmark.
license: Apache-2.0
metadata:
  author: Santiago Mattiauda
  version: "1.0"
---

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

### Profile-in-Release Mandate

> **CRITICAL**: Previews run in the same JVM/LayoutLib environment as debug builds — they do NOT reflect release performance. Debug and preview environments disable R8, inlining, and Strong Skipping Mode, making ALL numbers meaningless for performance. NEVER use debug builds or Previews as a performance baseline. Always profile a `release` or `benchmark` build type on a real device.

```kotlin
// ❌ WRONG: profiling debug build numbers
./gradlew assembleDebug  // measurements here are invalid

// ✅ CORRECT: always profile release or benchmark
./gradlew assembleBenchmark  // or assembleRelease with profileable=true
```

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
- Writing or configuring `@Preview` for a composable
- Wrapping all previews with a custom theme using `@PreviewWrapper`
- Creating data-driven previews with `@PreviewParameter`
- Deciding between screenshot testing libraries (Paparazzi vs Roborazzi vs instrumented)
- Enabling or interpreting Compose Compiler Reports (stability analysis)
- Adding Composition Tracing to diagnose frame-timing problems
- Setting up Layout Inspector for recomposition count debugging
- Configuring Macrobenchmark for performance regression gates

---

## CMP Applicability

> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)

| Source set | Status | Notes |
|------------|--------|-------|
| `commonMain` | ⚠️ | JetBrains `@Preview` ✅; `runComposeUiTest` ✅; Paparazzi/Macrobenchmark/Layout Inspector ❌ |
| `androidMain` | ✅ | Full skill content applies; Android Studio `@Preview` + all tooling available |
| `iosMain` | ⚠️ | JetBrains `@Preview` ✅ (Fleet/IJ); Compose Hot Reload ✅; use Instruments for profiling |
| `desktopMain` | ⚠️ | JetBrains `@Preview` ✅; Compose Hot Reload ✅; use JFR/JVisualVM for profiling |
| `wasmJsMain` | ⚠️ | JetBrains `@Preview` ✅ (limited); use Chrome DevTools for profiling |

**Status legend**: ✅ fully supported · ⚠️ partial / version-gated · ❌ Android-only.

**Android-only tools** (do NOT suggest for CMP non-Android targets):
- **Paparazzi** — Android/JVM renderer only
- **Macrobenchmark** — requires Android device/emulator
- **Baseline Profiles** — AGP + Android only
- **Layout Inspector** — Android Studio only

**CMP-compatible tools**: JetBrains `@Preview` (CMP 1.5+, Fleet/IJ), Compose Hot Reload (experimental), `runComposeUiTest` (commonTest), Compose Compiler Reports (all targets), Roborazzi ⚠️ (1.7+, Android JVM runner).

See full tooling matrix: [`references/cmp-tooling-matrix.md`](references/cmp-tooling-matrix.md).

---

## Critical Patterns

### 1. `@PreviewWrapper` + `PreviewWrapperProvider` — New April 2026

> **NEW April 2026 — NOT in pre-2026 docs**: `@PreviewWrapper` was introduced in April 2026. Do not expect it in documentation predating this date.

`@PreviewWrapper` lets you define a single composable wrapper that is automatically applied to ALL `@Preview` annotations in the module. This eliminates the need to manually wrap every preview with your theme.

```kotlin
// Step 1: Define the wrapper
class AppThemePreviewWrapper : PreviewWrapperProvider {
    @Composable
    override fun PreviewWrapper(content: @Composable () -> Unit) {
        AppTheme(darkTheme = false) {
            Surface { content() }
        }
    }
}

// Step 2: Register it (in your module's build.gradle.kts or via @PreviewWrapper annotation)
@PreviewWrapper(AppThemePreviewWrapper::class)
annotation class AppPreview

// Step 3: Use it — the wrapper is applied automatically
@AppPreview
@Composable
fun MyButtonPreview() {
    MyButton(text = "Save", onClick = {})
}
```

Without `@PreviewWrapper`, every preview file manually wraps content in the theme, causing drift when the theme signature changes.

### 2. `@PreviewParameter` — Data-Driven Previews

`@PreviewParameter` generates one preview instance per value in the provider, covering multiple states automatically.

```kotlin
class UserStateProvider : PreviewParameterProvider<UserState> {
    override val values = sequenceOf(
        UserState.Loading,
        UserState.Success(name = "Jane Doe"),
        UserState.Error(message = "Network timeout"),
    )
}

@Preview
@Composable
fun UserCardPreview(
    @PreviewParameter(UserStateProvider::class) state: UserState
) {
    UserCard(state = state)
}
```

**Decision**: use `@PreviewParameter` for components with distinct state variants (loading/success/error). Do NOT use it for exhaustive enum coverage that would produce >10 previews — that degrades IDE performance.

### 3. Screenshot Testing — ALPHA Warning

> **ALPHA — Screenshot Testing Activity (androidx.compose.ui.test.screenshot): 0.0.1-alpha14**: API may break between releases. Requires AGP 8.5+ for full functionality; AGP 9.0+ for IDE integration. Prefer Paparazzi or Roborazzi for production CI pipelines.

```kotlin
// Stable alternatives (NOT alpha):
// Paparazzi: JVM-based, no emulator needed, fast CI feedback
// Roborazzi: Robolectric-based, closer to Android runtime, strong diff reports
// Shot: instrumentation-based, real Android runtime, slower
// Dropshots: instrumentation-based, in-test comparison
```

**Decision tree for screenshot library**:
```
Do you need a real Android runtime?
├── YES → Shot or Dropshots (instrumentation-based, real device/emulator)
└── NO  → Do you already use Robolectric?
          ├── YES → Roborazzi (natural fit, strong diffs)
          └── NO  → Paparazzi (fast, LayoutLib-based, simplest setup)
```

### 4. Profile-in-Release Mandate

Debug builds disable:
- R8 optimization (code shrinking + inlining)
- Strong Skipping Mode (all lambdas treated as unstable)
- Compose Compiler optimizations

Result: any performance number from a debug build is **meaningless** for production decisions. Configure `benchmark` build type:

```kotlin
// build.gradle.kts — benchmark build type
buildTypes {
    create("benchmark") {
        initWith(getByName("release"))
        signingConfig = signingConfigs.getByName("debug")
        matchingFallbacks += listOf("release")
        isDebuggable = false
    }
}
```

### 5. Compose Compiler Reports

Reports show stability status of every composable's parameters. Run ONLY on release/benchmark builds.

```kotlin
// build.gradle.kts
composeCompiler {
    reportsDestination = layout.buildDirectory.dir("compose_compiler")
    metricsDestination = layout.buildDirectory.dir("compose_compiler")
}
```

Interpret the output:
- `restartable` — composable can skip if inputs unchanged (good)
- `skippable` — composable WILL skip on recomposition if stable inputs unchanged (best)
- `unstable` — composable ALWAYS recomposes (investigate)

```bash
# Generate reports
./gradlew assembleRelease

# Find new unstable types introduced in a PR (CI gate)
grep "unstable" build/compose_compiler/*-classes.txt
```

### 6. Composition Tracing — ProGuard Rule for Release

Composition Tracing inserts trace markers for Android Studio's CPU Profiler. These markers must NOT be stripped by R8 in release builds.

```proguard
# Keep composition tracing markers in release
-keep class androidx.compose.runtime.CompositionTracing { *; }
-keepclassmembers class ** {
    @androidx.compose.runtime.Composable <methods>;
}
```

Add the `runtime-tracing` artifact:

```kotlin
// libs.versions.toml
compose-runtime-tracing = { group = "androidx.compose.runtime", name = "runtime-tracing", version = "..." }
```

### 7. Layout Inspector Requirements

- Android device/emulator: **API 29+**
- Compose: **1.2+**
- Enable: `View > Tool Windows > Layout Inspector` in Android Studio

Use it to inspect:
- Recomposition counts per composable (shows which ones fire excessively)
- Semantics tree (for accessibility debugging)
- Layer hierarchy and modifier chains

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| Profiling in debug build | Switch to `benchmark` or `release` build type | Numbers are meaningless |
| Wrapping each preview with theme manually | Use `@PreviewWrapper` (April 2026+) | Maintenance drift |
| Using `@PreviewParameter` with >10 values | Limit to meaningful state variants | IDE preview rendering degradation |
| Screenshot tests via alpha `androidx.compose.ui.test.screenshot` on CI | Use Paparazzi or Roborazzi for stable CI | API may break on alpha update |
| Composition Tracing stripped by R8 | Add ProGuard keep rule | Traces missing in profiler |
| Running Layout Inspector on API <29 | Requires API 29+ device | Inspector not available |
| Running Compiler Reports on debug build | Append `:assembleRelease` | Reports reflect unoptimized code |

---

## Code Examples

### Full Preview Setup with @PreviewWrapper

```kotlin
// ThemePreviewWrapper.kt
class AppThemeWrapper : PreviewWrapperProvider {
    @Composable
    override fun PreviewWrapper(content: @Composable () -> Unit) {
        MaterialTheme { Surface(color = MaterialTheme.colorScheme.background) { content() } }
    }
}

@PreviewWrapper(AppThemeWrapper::class)
@Preview(showBackground = true)
annotation class AppPreview

@PreviewWrapper(AppThemeWrapper::class)
@Preview(showBackground = true, uiMode = UI_MODE_NIGHT_YES)
annotation class AppPreviewDark

// Usage
@AppPreview
@AppPreviewDark
@Composable
fun PrimaryButtonPreview() {
    PrimaryButton(text = "Confirm", onClick = {})
}
```

### Paparazzi Screenshot Test

```kotlin
@RunWith(JUnit4::class)
class MyButtonScreenshotTest {
    @get:Rule
    val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_6,
    )

    @Test
    fun button_defaultState() {
        paparazzi.snapshot {
            MyButton(text = "Save", onClick = {})
        }
    }
}
```

---

## Commands

```bash
# Generate Compose Compiler Reports (release only)
./gradlew assembleRelease

# Check for unstable composables in CI
grep "unstable" app/build/compose_compiler/*-classes.txt

# Record Paparazzi baselines
./gradlew recordPaparazziDebug

# Verify Paparazzi screenshots in CI
./gradlew verifyPaparazziDebug

# Record Roborazzi baselines
./gradlew recordRoborazziDebug
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Recomposition mechanics that previews expose |
| `compose-modifier-system` | `../compose-modifier-system/SKILL.md` | Layout/draw phase costs visible in Layout Inspector |
| `compose-effects` | `../compose-effects/SKILL.md` | Effects that run in previews (and how to stub them) |
| `compose-animations` | `../compose-animations/SKILL.md` | Animation tooling (label parameter, graphicsLayer tracing) |
| `compose-architecture` | `../compose-architecture/SKILL.md` | ViewModel-free Content composables make preview setup easier |
| `compose-navigation-nav3` | `../compose-navigation-nav3/SKILL.md` | Navigation entry previews and per-entry state |
| `compose-quality` | `../compose-quality/SKILL.md` | Accessibility assertions complement screenshot tests |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/previews-and-parameters.md](references/previews-and-parameters.md) | @Preview, @PreviewWrapper, @PreviewParameter |
| [references/performance-profiling.md](references/performance-profiling.md) | Baseline Profiles, Compiler Reports, Macrobenchmark |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx, AGP 8.5+
- **Stable APIs**: `@Preview`, `@PreviewParameter`, `ComposeCompilerReports`, `Layout Inspector` (API 29+, Compose 1.2+), Paparazzi, Roborazzi
- **New (April 2026)**: `@PreviewWrapper` + `PreviewWrapperProvider` — not in pre-2026 docs
- **Experimental/Alpha**: Screenshot Testing Activity `androidx.compose.ui.test.screenshot:0.0.1-alpha14` — API may break; prefer Paparazzi/Roborazzi for CI
- **Layout Inspector**: API 29+, Compose 1.2+
- **Review cadence**: Quarterly
