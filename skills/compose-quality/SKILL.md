---
name: compose-quality
description: >
  Jetpack Compose UI quality: accessibility semantics (mergeDescendants, customActions,
  liveRegion, traversalIndex), Compose UI testing (selectors, matchers, assertions),
  screenshot testing (Paparazzi, Roborazzi, alpha banner), and TalkBack/Switch Access
  validation. Trigger: when writing UI tests for Compose, adding accessibility semantics,
  choosing between onNodeWithTag vs onNodeWithText, implementing swipe-to-dismiss with
  accessible custom actions, configuring screenshot testing, or reviewing accessibility.
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

### Merged Semantics Tree — Cheaper Default

```kotlin
// The test API queries the MERGED tree by default — this is cheaper
// Merged tree: parent nodes absorb children's semantics (fewer nodes to traverse)
composeTestRule.onNodeWithText("Save")  // searches merged tree by default

// ✅ Default (useUnmergedTree = false) — correct for most cases
composeTestRule.onNodeWithText("Save").performClick()

// ⚠️ useUnmergedTree = true — only when you need child semantics hidden by merging
composeTestRule.onNodeWithText("Save", useUnmergedTree = true)
// Cost: traverses every raw semantics node including merged-away children
// Use ONLY when a specific child node has been absorbed by mergeDescendants = true
// and you need to assert on that child directly
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
- Adding accessibility semantics to custom Compose components
- Writing or reviewing UI tests for Compose screens
- Deciding between `onNodeWithTag`, `onNodeWithText`, or `onNodeWithContentDescription`
- Implementing swipe-to-dismiss, drag-and-drop, or other gesture-driven interactions that must be accessible
- Choosing a screenshot testing library (Paparazzi, Roborazzi, Shot, Dropshots)
- Validating traversal order with TalkBack or Switch Access

---

## When to Use This vs compose-previews-tooling

`compose-quality` covers the semantics layer, UI test API, and runtime accessibility behavior. `compose-previews-tooling` covers static tooling: `@Preview`, compiler reports, Layout Inspector configuration, and Macrobenchmark setup. Use both together when working on accessibility + visual regression testing.

---

## Critical Patterns

### 1. `mergeDescendants = true` — Logical UI Groupings

When a container represents ONE logical accessible element (e.g., a list item with icon + title + subtitle), merge its children into a single semantics node.

```kotlin
// ✅ The entire row is one accessible unit — TalkBack reads it as one item
Row(
    modifier = Modifier
        .clickable { onItemClick() }
        .semantics(mergeDescendants = true) {}
) {
    Icon(imageVector = Icons.Default.Favorite, contentDescription = null) // null = decorative
    Column {
        Text("Jane Doe")
        Text("Active 2 min ago")
    }
}
// TalkBack announces: "Jane Doe, Active 2 min ago, button" — one focused item

// ❌ Without mergeDescendants: TalkBack focuses each child separately
// → 3 separate focus stops: Icon (reads nothing), "Jane Doe", "Active 2 min ago"
```

### 2. `clearAndSetSemantics { }` + `hideFromAccessibility()`

Use `clearAndSetSemantics` when you need FULL control over what accessibility services see — it clears all children's semantics and replaces with your explicit block.

Use `hideFromAccessibility()` (`Modifier.semantics { invisibleToUser() }`) for elements that are purely decorative but STILL rendered.

```kotlin
// ✅ clearAndSetSemantics — replace all child semantics with one explicit description
Box(
    Modifier.clearAndSetSemantics {
        contentDescription = "Profile: Jane Doe, 3 unread messages"
        role = Role.Button
    }
) {
    Avatar(user = user)        // semantics cleared
    Text(user.name)            // semantics cleared
    Badge(count = 3)           // semantics cleared
}

// ✅ hideFromAccessibility — element exists in layout but invisible to accessibility tree
Image(
    painter = decorativePainter,
    contentDescription = null,
    modifier = Modifier.semantics { invisibleToUser() }
)
```

### 3. `customActions` — REQUIRED for Gesture-Driven Interactions

Switch Access and Voice Access CANNOT discover swipe-to-dismiss, drag-and-drop, or any gesture-only action unless you expose it via `customActions`. This is not optional for accessible apps.

```kotlin
// ❌ Swipe-to-dismiss without customActions: invisible to Switch Access / Voice Access
val dismissState = rememberDismissState()
SwipeToDismiss(
    state = dismissState,
    background = { DismissBackground(dismissState) },
    dismissContent = { InboxItem(item) }
)

// ✅ Expose the action via customActions
Box(
    modifier = Modifier.semantics {
        customActions = listOf(
            CustomAccessibilityAction(label = "Delete item") {
                onDelete(item)
                true
            },
            CustomAccessibilityAction(label = "Archive item") {
                onArchive(item)
                true
            }
        )
    }
) {
    SwipeToDismiss(...)
}
```

**Rule**: any interaction that is ONLY achievable through a pointer gesture (swipe, drag, long-press reveal) MUST have a `customAction` equivalent.

### 4. `liveRegion` — Dynamic Content Announcements

Mark content that changes without user action (status messages, validation errors, snackbars, loading results) as a live region so TalkBack announces updates automatically.

```kotlin
var statusMessage by remember { mutableStateOf("") }

Text(
    text = statusMessage,
    modifier = Modifier.semantics {
        liveRegion = LiveRegionMode.Polite  // announces update, waits for idle
        // LiveRegionMode.Assertive — interrupts current announcement (use sparingly)
    }
)

// When statusMessage changes, TalkBack speaks it without focus movement
statusMessage = "Message sent successfully"
```

**Caution**: too many live regions create announcement noise. Use `Polite` by default; `Assertive` only for critical errors.

### 5. `traversalIndex` + `isTraversalGroup` — Non-Standard Reading Order

Default TalkBack traversal: top-to-bottom, left-to-right. Override when visual design creates a reading order mismatch (e.g., FAB above list, overlapping panels).

```kotlin
// Lower traversalIndex values are read FIRST
Scaffold(
    floatingActionButton = {
        FloatingActionButton(
            onClick = { onAddItem() },
            modifier = Modifier.semantics {
                traversalIndex = -1f  // ← FAB is read before the list below it
            }
        ) { Icon(Icons.Default.Add, contentDescription = "Add item") }
    }
) {
    LazyColumn(modifier = Modifier.semantics { isTraversalGroup = true }) {
        // isTraversalGroup = true: treat the list as a single traversal unit
        items(items) { ItemRow(it) }
    }
}
```

### 6. Screenshot Testing — ALPHA Banner + Stable Alternatives

> **ALPHA — Screenshot Testing Activity (androidx.compose.ui.test.screenshot): 0.0.1-alpha14**: API may break. Requires AGP 8.5+ (AGP 9.0+ for IDE integration). For production CI, prefer Paparazzi or Roborazzi.

| Library | Runtime | Speed | Real Android | Best For |
|---------|---------|-------|--------------|---------|
| Paparazzi | JVM/LayoutLib | Fast | No | Fast CI, design system components |
| Roborazzi | JVM/Robolectric | Fast | Closer | Projects with Robolectric, diff reports |
| Shot | Instrumentation | Slow | Yes | Pixel-accurate on real runtime |
| Dropshots | Instrumentation | Slow | Yes | In-test assertions on device |
| `androidx screenshot` | Instrumentation | Slow | Yes | **ALPHA — avoid for production CI** |

### 7. Test Selector Preference: `onNodeWithTag` > `onNodeWithText`

```kotlin
// ❌ Fragile — breaks on text changes, localization, dynamic content
composeTestRule
    .onNodeWithText("Submit Order")
    .performClick()

// ✅ Stable — survives text changes, localization, copy edits
Modifier.testTag("submit_order_button")

composeTestRule
    .onNodeWithTag("submit_order_button")
    .performClick()

// Priority for selectors (best to worst):
// 1. onNodeWithContentDescription — accessible + meaningful
// 2. onNodeWithTag (testTag) — stable, implementation-independent
// 3. onNodeWithText — fragile to copy changes
// 4. hasRole + matcher combos — good for custom component type assertions
```

`testTag` is a fallback when semantics cannot provide a unique, stable identifier. It should SUPPORT a semantics-first strategy, not replace it.

### 8. `useUnmergedTree = true` — Explicit Opt-In Only

The default (`false`) queries the merged semantics tree, which is faster and matches what accessibility services see. Use `true` ONLY when you specifically need to assert on a child that has been absorbed by `mergeDescendants = true`.

```kotlin
// ✅ Default — correct for 95% of tests
composeTestRule.onNodeWithText("Settings")

// ⚠️ Only when you need to find a child inside a mergeDescendants container
composeTestRule.onNodeWithText("Subtitle text", useUnmergedTree = true)
```

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| Swipe-to-dismiss without `customActions` | Add `customActions` for Delete/Archive/Move | Switch Access + Voice Access cannot find the action |
| `mergeDescendants = true` on large subtrees | Merge at the logical item level, not page level | Over-merging hides important semantics |
| `clearAndSetSemantics` hiding interactive children | Only use on purely presentational wrappers | Accessibility actions lost |
| `liveRegion = Assertive` for non-critical messages | Use `Polite` for status messages | Interrupts TalkBack mid-sentence |
| Using `onNodeWithText` for localized/dynamic text | Switch to `onNodeWithTag` or `onNodeWithContentDescription` | Flaky tests on string changes |
| `useUnmergedTree = true` by default in all tests | Remove — use `false` (cheaper) unless explicitly needed | Slower traversal, tests don't match a11y surface |
| Screenshot tests via alpha library in CI | Use Paparazzi or Roborazzi (stable) | CI breaks on alpha API changes |

---

## Code Examples

### Accessible Inbox List Item

```kotlin
@Composable
fun InboxItem(
    item: InboxItem,
    onDelete: () -> Unit,
    onArchive: () -> Unit,
) {
    val dismissState = rememberDismissState()

    Box(
        modifier = Modifier.semantics {
            customActions = listOf(
                CustomAccessibilityAction("Delete") { onDelete(); true },
                CustomAccessibilityAction("Archive") { onArchive(); true },
            )
        }
    ) {
        SwipeToDismiss(
            state = dismissState,
            background = { DismissBackground(dismissState) },
            dismissContent = {
                Row(
                    modifier = Modifier.semantics(mergeDescendants = true) {}
                ) {
                    Icon(Icons.Default.Email, contentDescription = null)
                    Column {
                        Text(item.sender)
                        Text(item.preview)
                    }
                }
            }
        )
    }
}
```

### Compose UI Test — Best Practices

```kotlin
@RunWith(AndroidJUnit4::class)
class InboxScreenTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun deleteAction_isExposedToAccessibility() {
        composeTestRule.setContent {
            InboxScreen(items = fakeItems)
        }

        // Assert semantic action exists (not just visual swipe)
        composeTestRule
            .onNodeWithContentDescription("Delete")  // or onNodeWithTag("inbox_item_0")
            .assertHasClickAction()
    }

    @Test
    fun submittingForm_showsSuccessMessage() {
        composeTestRule.setContent { ContactForm() }

        composeTestRule.onNodeWithTag("email_field").performTextInput("jane@example.com")
        composeTestRule.onNodeWithTag("submit_button").performClick()

        // Assert on semantics, not implementation state
        composeTestRule.onNodeWithText("Message sent!").assertIsDisplayed()
    }
}
```

### Paparazzi Screenshot Test

```kotlin
@RunWith(JUnit4::class)
class InboxItemScreenshotTest {

    @get:Rule
    val paparazzi = Paparazzi(deviceConfig = DeviceConfig.PIXEL_6)

    @Test fun inboxItem_defaultState() {
        paparazzi.snapshot { InboxItem(item = fakeItem, onDelete = {}, onArchive = {}) }
    }

    @Test fun inboxItem_darkTheme() {
        paparazzi.snapshot {
            MaterialTheme(colorScheme = darkColorScheme()) {
                InboxItem(item = fakeItem, onDelete = {}, onArchive = {})
            }
        }
    }
}
```

---

## Commands

```bash
# Run Compose UI tests
./gradlew connectedAndroidTest

# Record Paparazzi baselines
./gradlew recordPaparazziDebug

# Verify Paparazzi (CI)
./gradlew verifyPaparazziDebug

# Record Roborazzi baselines
./gradlew recordRoborazziDebug

# Verify Roborazzi (CI)
./gradlew verifyRoborazziDebug

# Check no web URLs in references (CC3 contract)
grep -r "https\?://" skills/*/references/
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Recomposition mechanics — affects which semantics nodes exist at test time |
| `compose-previews-tooling` | `../compose-previews-tooling/SKILL.md` | Screenshot testing libraries, @PreviewParameter for state coverage |
| `compose-architecture` | `../compose-architecture/SKILL.md` | Screen/Content split makes UI testable without ViewModel in previews |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/accessibility-semantics.md](references/accessibility-semantics.md) | Semantics, mergeDescendants, customActions |
| [references/ui-testing.md](references/ui-testing.md) | Compose UI tests, finders, useUnmergedTree |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx, Strong Skipping Mode (default)
- **Stable APIs**: `Modifier.semantics`, `mergeDescendants`, `clearAndSetSemantics`, `customActions`, `liveRegion`, `traversalIndex`, `isTraversalGroup`, `testTag`, Compose UI test API, Paparazzi, Roborazzi
- **Experimental/Alpha**: Screenshot Testing Activity `0.0.1-alpha14` — API may break; requires AGP 8.5+/9.0+; prefer Paparazzi/Roborazzi for CI
- **Review cadence**: Quarterly
