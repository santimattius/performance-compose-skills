# CMP Tooling Matrix

> **Discovery validated**: May 2026 — official JetBrains CMP tooling docs.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

This reference details which tooling from `compose-previews-tooling` is available per platform and what the CMP equivalents are.

---

## Full Tooling Availability Matrix

| Tool | Android | iOS | Desktop (JVM) | Web (wasmJs) | Notes |
|------|:-------:|:---:|:-------------:|:------------:|-------|
| **Android Studio `@Preview`** | ✅ | ❌ | ❌ | ❌ | AGP-integrated; no CMP equivalent in Android Studio |
| **JetBrains `@Preview`** | ✅ | ✅ | ✅ | ✅ | CMP 1.5+; `org.jetbrains.compose.ui.tooling`; available in Fleet / IntelliJ IDEA |
| **Compose Hot Reload** | ✅ | ✅ | ✅ | ✅ | JetBrains plugin; experimental; live code changes without restart |
| **`@PreviewParameter`** | ✅ | ✅ | ✅ | ✅ | Works with both Android Studio and JetBrains `@Preview` |
| **Layout Inspector** | ✅ | ❌ | ❌ | ❌ | Android Studio only; no CMP equivalent |
| **Paparazzi** | ✅ | ❌ | ❌ | ❌ | JVM/Android renderer; cannot render iOS or wasm UI |
| **Roborazzi** | ✅ | ⚠️ | ⚠️ | ❌ | 1.7+; iOS/Desktop run via JVM runner with device-frame limitations |
| **Macrobenchmark** | ✅ | ❌ | ❌ | ❌ | Android profiling infrastructure; no CMP equivalent |
| **Baseline Profiles** | ✅ | ❌ | ❌ | ❌ | Android AOT compilation; no CMP equivalent |
| **Compose Compiler Reports** | ✅ | ✅ | ✅ | ✅ | Works across all KMP targets with Kotlin 2.0+ |
| **`runComposeUiTest`** | ✅ | ✅ | ✅ | ✅ | `org.jetbrains.compose.ui:ui-test`; use in `commonTest` |
| **`compose-ui-test-junit4`** | ✅ | ❌ | ❌ | ❌ | Android JUnit4 rule only; not CMP |
| **Composition Tracing** | ✅ | ❌ | ❌ | ❌ | Android Studio profiler; no CMP equivalent |
| **iOS Instruments** | ❌ | ✅ | ❌ | ❌ | Native iOS profiling; use for iOS performance |
| **JFR / JVisualVM** | ❌ | ❌ | ✅ | ❌ | JVM desktop profiling |
| **Chrome DevTools** | ❌ | ❌ | ❌ | ✅ | wasm/JS profiling |

**Status legend**: ✅ fully supported · ⚠️ partial / caveats apply · ❌ not available.

---

## Android-Only Block (DO NOT use for CMP commonMain)

These tools only work with Android. Do NOT recommend them for CMP projects targeting non-Android platforms.

- **Paparazzi** — renders Android UI on JVM; iOS/Desktop UI not supported
- **Macrobenchmark** — requires a physical/virtual Android device
- **Baseline Profiles** — AGP plugin; Android AOT only
- **Layout Inspector** — Android Studio plugin; Android runtime only
- **Composition Tracing** — Android Studio profiler integration
- **`compose-ui-test-junit4` TestRule** — Android JUnit4 infrastructure

---

## CMP-Compatible Tooling Block

These tools work across all CMP targets.

### JetBrains `@Preview` (CMP 1.5+)

```kotlin
// commonMain — works in all targets
import org.jetbrains.compose.ui.tooling.preview.Preview

@Preview
@Composable
fun MyComponentPreview() {
    MyComponent()
}
```

Available in **Fleet** and **IntelliJ IDEA** with the Compose Multiplatform plugin. Android Studio renders Android-targeted previews; use Fleet for cross-platform previews.

### Compose Hot Reload

Live code change propagation without restarting the app. Experimental. Requires JetBrains toolchain.

```kotlin
// build.gradle.kts
plugins {
    id("org.jetbrains.compose.hot-reload") version "..." apply false
}
```

### runComposeUiTest (commonTest)

```kotlin
// commonTest — CMP UI testing
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.runComposeUiTest

@OptIn(ExperimentalTestApi::class)
class MyComponentTest {
    @Test
    fun checkText() = runComposeUiTest {
        setContent { MyComponent() }
        onNodeWithText("Hello").assertIsDisplayed()
    }
}
```

Run on all platforms:
- `./gradlew iosSimulatorArm64Test`
- `./gradlew jvmTest`
- `./gradlew wasmJsTest`
- `./gradlew connectedAndroidTest`

See full CMP UI testing guide: [compose-quality/references/cmp-ui-testing.md](../../compose-quality/references/cmp-ui-testing.md)

### Roborazzi (⚠️ caveat for CMP)

Roborazzi 1.7+ supports screenshot tests for CMP projects, but runs on the **JVM (Android) runner**. Screenshots reflect what the Android renderer produces — not exact iOS or Desktop rendering. Use for cross-platform smoke tests only; supplement with platform-native screenshot tools for pixel-perfect comparison.

```kotlin
// androidTest — Roborazzi screenshot test (also usable for CMP components on Android renderer)
@Test
fun captureMyComponent() {
    composeTestRule.setContent { MyComponent() }
    composeTestRule.onRoot().captureRoboImage()
}
```

---

## Decision Guide: Android vs CMP tooling

| Question | Android project | CMP project |
|----------|----------------|-------------|
| UI previews | Android Studio `@Preview` | JetBrains `@Preview` (Fleet/IJ) |
| Screenshot tests | Paparazzi or Roborazzi | Roborazzi ⚠️ (Android runner only) |
| UI tests | `compose-ui-test-junit4` | `runComposeUiTest` in `commonTest` |
| Performance profiling | Macrobenchmark + Baseline Profiles | iOS Instruments / JFR / Chrome DevTools per platform |
| Live code changes | Hot Reload (Android Studio) | Compose Hot Reload (JetBrains) |
| Stability/skippability reports | Compose Compiler Reports | Compose Compiler Reports ✅ |

---

## Validation

- **Validated**: 2026-05 (official JetBrains CMP tooling docs)
- **JetBrains `@Preview` min version**: CMP 1.5+
- **Roborazzi CMP min version**: 1.7+
- **Review cadence**: Quarterly
