# CMP iOS Accessibility

> **Discovery validated**: May 2026 — official JetBrains CMP iOS Accessibility docs.
> Canonical CMP platform rules: [`../../_shared/cmp-platform.md`](../../_shared/cmp-platform.md)

Compose Multiplatform maps Compose semantics to native iOS accessibility APIs automatically. This reference documents the mapping, configuration options, and testing approach for iOS accessibility in CMP apps.

---

## Semantics → VoiceOver Mapping

Compose semantics properties are automatically bridged to iOS VoiceOver via UIAccessibility. The mapping happens in `ComposeUIViewController`.

| Compose semantics | iOS VoiceOver / UIAccessibility |
|-------------------|--------------------------------|
| `contentDescription` | `accessibilityLabel` |
| `testTag` | `accessibilityIdentifier` |
| `role = Role.Button` | `UIAccessibilityTraitButton` |
| `role = Role.Image` | `UIAccessibilityTraitImage` |
| `stateDescription` | `accessibilityValue` |
| `onClick { }` | Activatable (double-tap) |
| `selected` | `UIAccessibilityTraitSelected` |
| `disabled` | `UIAccessibilityTraitNotEnabled` |
| `liveRegion` | `UIAccessibilityAnnouncementNotification` |
| `mergeDescendants = true` | Flattened into single accessibility element |
| `heading` | `UIAccessibilityTraitHeader` |
| `traversalIndex` | Accessibility element ordering |

### testTag as accessibilityIdentifier

`testTag` serves dual purpose in CMP: test targeting in `runComposeUiTest` AND native iOS `accessibilityIdentifier` (usable in XCTest UI tests).

```kotlin
// commonMain — tag for both Compose tests and XCTest
Box(Modifier.testTag("submit_button")) { ... }
```

```swift
// XCTest — access via accessibilityIdentifier
let button = app.buttons["submit_button"]
XCTAssertTrue(button.exists)
```

---

## ComposeUIViewController Setup

Configure accessibility sync behavior on the `ComposeUIViewController` factory:

```kotlin
// iosMain — configure accessibility sync
fun MainViewController() = ComposeUIViewController(
    configure = {
        // Control how often semantics tree syncs to UIAccessibility
        accessibilitySyncOptions = AccessibilitySyncOptions.WhenRequiredByAccessibility()
        // Options: Always(), Never(), WhenRequiredByAccessibility() (default)
    }
) {
    App()
}
```

### AccessibilitySyncOptions values

| Option | Behaviour | Use when |
|--------|-----------|----------|
| `WhenRequiredByAccessibility()` | Sync only when VoiceOver/Switch Control is active | Default — best performance |
| `Always()` | Sync on every frame | Debugging accessibility tree; XCTest automation |
| `Never()` | Disable sync entirely | Non-interactive content; custom a11y implementation |

> For XCTest `performAccessibilityAudit()` to pass, semantics must be synced. Use `Always()` in test builds if needed.

---

## Writing CMP-Accessible Components

### Buttons and clickable elements

```kotlin
// commonMain — works on Android and iOS
Box(
    Modifier
        .clickable(
            onClickLabel = "Submit form",
            onClick = onSubmit
        )
        .semantics {
            contentDescription = "Submit"
            role = Role.Button
        }
) { Text("Submit") }
```

### Images

```kotlin
Image(
    painter = painterResource(Res.drawable.logo),
    contentDescription = "Company logo",  // null for decorative
    modifier = Modifier.semantics { role = Role.Image }
)
```

### Merged containers

```kotlin
// Merge card content into single VoiceOver element
Card(
    modifier = Modifier.semantics(mergeDescendants = true) { }
) {
    Text(product.name)
    Text(product.price)
    // VoiceOver reads: "Product Name, $9.99"
}
```

---

## High-Contrast Support

CMP does not automatically detect the iOS High Contrast accessibility setting. Implement manual detection in `iosMain`:

```kotlin
// iosMain — detect high contrast via UIAccessibility
actual fun isHighContrastEnabled(): Boolean =
    UIAccessibility.isDarkerSystemColorsEnabled()
```

```kotlin
// commonMain — expect declaration
expect fun isHighContrastEnabled(): Boolean

// Usage in shared UI
@Composable
fun AdaptiveText(text: String) {
    val highContrast = remember { isHighContrastEnabled() }
    Text(
        text = text,
        color = if (highContrast) Color.Black else MaterialTheme.colorScheme.onSurface
    )
}
```

> Note: Dynamic contrast changes while the app is running require additional observation via `UIAccessibility.darkerSystemColorsStatusDidChangeNotification`.

---

## Testing iOS Accessibility

### XCTest — performAccessibilityAudit (Xcode 15+)

Run a system-level accessibility audit against the running app:

```swift
// XCTest — UITest target
func testAccessibilityAudit() throws {
    let app = XCUIApplication()
    app.launch()
    
    try app.performAccessibilityAudit()
    // Throws XCTAssertionError for contrast, labels, hit-target issues
}
```

> Requires iOS 17 Simulator or device. Checks: contrast ratio, missing labels, hit target size, dynamic type support.

### Filtering specific audits

```swift
try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .elementDetection]) { issue in
    // Return true to ignore known issues
    var shouldIgnore = false
    if issue.auditType == .contrast, issue.element.label == "Decorative" {
        shouldIgnore = true
    }
    return shouldIgnore
}
```

### Compose UI tests (commonTest)

```kotlin
// commonTest — verify semantics in runComposeUiTest
@OptIn(ExperimentalTestApi::class)
class AccessibilityTest {
    @Test
    fun submitButtonHasLabel() = runComposeUiTest {
        setContent { SubmitButton(onClick = {}) }
        onNodeWithContentDescription("Submit").assertExists()
        onNodeWithTag("submit_button").assertHasClickAction()
    }
}
```

Run on iOS: `./gradlew iosSimulatorArm64Test`

---

## Checklist: iOS Accessibility in CMP

- [ ] All interactive elements have `contentDescription` or `onClickLabel`
- [ ] Decorative images use `contentDescription = null`
- [ ] Cards and compound elements use `mergeDescendants = true`
- [ ] `testTag` values are unique and match XCTest identifiers
- [ ] `AccessibilitySyncOptions` configured on `ComposeUIViewController`
- [ ] `performAccessibilityAudit()` passes in CI (use `Always()` sync in test builds)
- [ ] High-contrast palettes tested manually on device (Settings → Accessibility → Display & Text Size → Increase Contrast)
- [ ] `traversalIndex` set correctly for non-linear reading order

---

## Validation

- **Validated**: 2026-05 (official JetBrains CMP iOS Accessibility docs)
- **iOS min version**: iOS 16+ for full semantics support; `performAccessibilityAudit` requires iOS 17+ / Xcode 15+
- **`AccessibilitySyncOptions`**: available in CMP 1.6+
- **Review cadence**: Quarterly
