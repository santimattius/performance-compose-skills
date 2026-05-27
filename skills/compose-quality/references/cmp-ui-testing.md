# CMP UI Testing

> **Discovery validated**: May 2026 — official JetBrains CMP UI Testing docs.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

Compose Multiplatform provides `runComposeUiTest` for writing platform-agnostic UI tests in `commonTest`. Tests run on iOS Simulator, JVM Desktop, wasmJs, and Android — using the same test code.

---

## Setup

```kotlin
// build.gradle.kts (shared module)
commonTest.dependencies {
    implementation(kotlin("test"))
    implementation("org.jetbrains.compose.ui:ui-test:${compose_version}")
    // DO NOT add compose-ui-test-junit4 here — it's Android-only
}
```

> **IMPORTANT**: `compose-ui-test-junit4` (Android JUnit4 `ComposeTestRule`) is Android-only. Use `runComposeUiTest` from `org.jetbrains.compose.ui:ui-test` in `commonTest`.

---

## runComposeUiTest — core API

`runComposeUiTest` is the CMP equivalent of `createComposeRule()`. It is a suspend function that creates a composition, runs assertions, then tears down.

```kotlin
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.runComposeUiTest
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.assertIsDisplayed

@OptIn(ExperimentalTestApi::class)
class MyComponentTest {
    @Test
    fun textIsDisplayed() = runComposeUiTest {
        setContent {
            MyComponent(text = "Hello CMP")
        }
        onNodeWithText("Hello CMP").assertIsDisplayed()
    }
}
```

---

## Running tests on each platform

| Platform | Gradle task | Notes |
|---------|-------------|-------|
| iOS Simulator (arm64) | `./gradlew iosSimulatorArm64Test` | Requires Xcode + Simulator |
| iOS Simulator (x64) | `./gradlew iosX64Test` | Intel Mac hosts |
| JVM Desktop | `./gradlew jvmTest` | Fast; no emulator needed |
| wasm/JS | `./gradlew wasmJsTest` | Requires Node.js or browser runtime |
| Android (unit) | `./gradlew testDebugUnitTest` | Robolectric-backed |
| Android (instrumented) | `./gradlew connectedAndroidTest` | Requires device/emulator |

### androidDeviceTest setup (instrumented)

For instrumented Android tests that share the same `commonTest` code:

```kotlin
// androidMain source set — bridge to commonTest
@RunWith(AndroidJUnit4::class)
class AndroidInstrumentedTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<ComponentActivity>()
    // ... or use runComposeUiTest in shared commonTest
}
```

---

## Matchers and interactions

`runComposeUiTest` exposes the same semantics-based matcher API as Android's `compose-ui-test`:

```kotlin
runComposeUiTest {
    setContent { LoginScreen(onLogin = {}) }

    // Finders
    onNodeWithText("Email")
    onNodeWithTag("email_field")
    onNodeWithContentDescription("Submit")
    onAllNodesWithTag("item")

    // Interactions
    onNodeWithTag("email_field").performTextInput("user@example.com")
    onNodeWithTag("submit_button").performClick()

    // Assertions
    onNodeWithText("Welcome").assertIsDisplayed()
    onNodeWithTag("error_label").assertDoesNotExist()
    onNodeWithTag("submit_button").assertIsEnabled()
    onNodeWithTag("submit_button").assertHasClickAction()
}
```

---

## Waiting for async state

Use `waitUntil` for state that updates asynchronously:

```kotlin
runComposeUiTest {
    setContent { AsyncDataScreen(viewModel = vm) }

    waitUntil(timeoutMillis = 3_000) {
        onAllNodesWithTag("data_item").fetchSemanticsNodes().isNotEmpty()
    }

    onNodeWithTag("data_item").assertIsDisplayed()
}
```

---

## Shared test fixtures

Write reusable helpers in `commonTest` — they run on all platforms:

```kotlin
// commonTest/TestHelpers.kt
@OptIn(ExperimentalTestApi::class)
fun ComposeUiTest.assertButton(tag: String, label: String) {
    onNodeWithTag(tag)
        .assertIsDisplayed()
        .assertHasClickAction()
        .assertContentDescriptionEquals(label)
}
```

---

## Android-only vs CMP testing comparison

| Feature | Android (`compose-ui-test-junit4`) | CMP (`org.jetbrains.compose.ui:ui-test`) |
|---------|-----------------------------------|------------------------------------------|
| Entry point | `@get:Rule val rule = createComposeRule()` | `runComposeUiTest { }` |
| Scope | `androidTest` only | `commonTest` — all platforms |
| Finders | `onNodeWithText`, `onNodeWithTag`, etc. | Same API |
| Interactions | `performClick`, `performTextInput`, etc. | Same API |
| Assertions | `assertIsDisplayed`, `assertExists`, etc. | Same API |
| Async | `awaitIdle()`, `waitUntil` | `waitUntil` |
| Screenshot | Roborazzi (via JUnit rule) | Roborazzi ⚠️ Android runner only |

---

## Checklist: CMP UI testing

- [ ] UI tests live in `commonTest` using `runComposeUiTest`
- [ ] No `compose-ui-test-junit4` dependency in `commonTest` (Android-only)
- [ ] `testTag` applied to interactive elements for reliable targeting
- [ ] Tests run on `iosSimulatorArm64Test`, `jvmTest`, `wasmJsTest`, and `connectedAndroidTest` in CI
- [ ] Async state updates use `waitUntil` (not `Thread.sleep`)
- [ ] Shared test helpers in `commonTest` avoid platform imports

---

## Validation

- **Validated**: 2026-05 (official JetBrains CMP UI Testing docs)
- **Artifact**: `org.jetbrains.compose.ui:ui-test` (CMP version)
- **Min CMP version**: 1.5+
- **Review cadence**: Quarterly
