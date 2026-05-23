# UI Testing

## Philosophy

Compose UI tests verify **user-visible behavior** through the semantics tree — not implementation details. Same layer TalkBack uses → accessibility and testability align.

Good tests answer:
- Can the user find the element?
- Can they interact?
- Does the screen update correctly?
- Are semantics correct?

## Test Setup

```kotlin
@get:Rule
val composeTestRule = createComposeRule()  // Compose-only

// Or for Activity integration:
val composeTestRule = createAndroidComposeRule<MainActivity>()
```

Flow: `setContent { }` → find node → perform action → assert.

## Finder Hierarchy (prefer top → bottom)

| Priority | Finder | When |
|----------|--------|------|
| 1 | `onNodeWithText` | Visible text |
| 2 | `onNodeWithContentDescription` | Icons, unlabeled controls |
| 3 | `hasRole(Role.Button)` + matcher | Custom components |
| 4 | `onNodeWithTag` | Last resort — multiple similar elements |

```kotlin
composeTestRule.onNodeWithContentDescription("Delete").performClick()
composeTestRule.onNode(hasText("Saved")).assertExists()
```

If only `testTag` works, semantics are likely too weak — fix the component.

## useUnmergedTree

Default `false` (merged tree) — matches accessible surface, cheaper traversal.

```kotlin
onNodeWithTag("internal", useUnmergedTree = true)  // explicit opt-in only
```

Prefer merged tree unless testing nodes intentionally merged away from accessibility.

## Matchers and Actions

```kotlin
onNode(hasClickAction()).performClick()
onNode(hasText("Submit")).assertIsEnabled()
onNode(hasRole(Role.Switch)).assertIsOn()
```

## Screenshot Testing

Official Compose screenshot API is **alpha** (0.0.1-alpha14). Production CI:

| Tool | Notes |
|------|-------|
| **Paparazzi** | JVM, fast, no emulator |
| **Roborazzi** | Robolectric-based |
| **Shot** | Instrumentation, real runtime |
| **Dropshots** | Instrumentation, in-test diff |

See compose-previews-tooling references for selection decision tree.

## What UI Tests Don't Guarantee

- Visual polish, contrast, animation feel
- Full TalkBack flow comfort
- Performance

Combine: unit tests (logic) + UI tests (behavior) + manual a11y + screenshot (visual regression).

## Accessibility Assertions

```kotlin
onNode(hasContentDescription("Delete item")).assertExists()
onNode(hasRole(Role.Button)).assertExists()
onNode(isToggleable()).assertIsOn()
```

Custom components are the highest-risk area for missing semantics.

## Test Layer Split

| Layer | Tests |
|-------|-------|
| Domain / ViewModel | Unit tests — fast, isolated |
| Content composables | Compose UI tests with fake state |
| Full flows | Integration / instrumentation |

Do not put business logic verification solely in UI tests.
