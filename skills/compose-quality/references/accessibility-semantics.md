# Accessibility Semantics

## Four Accessibility Pillars in Compose

1. **Interaction areas** — 48dp minimum touch targets
2. **Visual contrast** — text/background, disabled states, errors
3. **Semantics** — meaning exposed to TalkBack and tests
4. **Content description** — non-text elements

## Touch Targets

Minimum **48.dp × 48.dp**. Prefer `IconButton` over raw `Icon` + `clickable`.

```kotlin
IconButton(onClick = {}) { Icon(..., contentDescription = "Favorite") }
// vs small Icon with clickable — insufficient target
```

## Semantics Merge

```kotlin
// Logical group — one TalkBack node
Row(modifier = Modifier.semantics(mergeDescendants = true) { ... }) { ... }

// Replace child semantics entirely
Modifier.clearAndSetSemantics {
    contentDescription = "Order #1234, delivered"
    role = Role.Button
}
```

`hideFromAccessibility()` on decorative elements.

## customActions — REQUIRED for Gestures

Swipe-to-dismiss, drag-and-drop, custom swipe actions MUST expose `customActions` for Switch Access / Voice Access:

```kotlin
Modifier.semantics {
    customActions = listOf(
        CustomAccessibilityAction("Dismiss") { onDismiss(); true }
    )
}
```

Without customActions, gesture-only interactions are inaccessible.

## liveRegion

Dynamic content updates (chat messages, timers, errors):

```kotlin
Modifier.semantics { liveRegion = LiveRegionMode.Polite }
```

## Traversal Order

```kotlin
Modifier.semantics {
    traversalIndex = 0f
    isTraversalGroup = true
}
```

Control TalkBack navigation order in custom layouts.

## Roles and State

```kotlin
Modifier.semantics {
    role = Role.Switch
    stateDescription = if (checked) "On" else "Off"
    contentDescription = "Airplane mode"
}
```

## Debugging

- Layout Inspector → semantics tree
- TalkBack manual testing on device
- Compose UI tests assert semantics (see ui-testing.md)

## Contrast Checklist

- Light and dark mode
- Large font scale
- High contrast mode
- Disabled state visibility (not just gray-on-gray)

## useUnmergedTree Default

Merged tree = cheaper, matches TalkBack surface. Default `useUnmergedTree = false`. Opt into unmerged only when testing internal nodes intentionally hidden by merge.
