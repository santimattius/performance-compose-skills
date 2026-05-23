# Layout Phase

## What Layout Does

Calculates width, height, x, y for each node. Does NOT draw pixels.

## Constraint Flow

```
Parent constraints ↓ measure children ↑ decide own size ↓ place children ↓
```

Parent `layout` modifier runs first; to know its size it measures children; placement flows top-down after measurement completes.

## `layout` Modifier

Universal layout-phase hook implementing `LayoutModifierNode`:

```kotlin
Modifier.layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    layout(placeable.width, placeable.height) {
        placeable.place(x, y)
    }
}
```

Can transform constraints passed to child and placement relative to parent.

## `offset` — Layout vs Composition

| API | Phase | Use when |
|-----|-------|----------|
| `Modifier.offset(x, y)` | Composition reads values | Static or rarely changing offsets |
| `Modifier.offset { IntOffset(x, y) }` | Layout lambda | Scroll, animation, frequent changes |

Coordinates in lambda overload are **pixels** (`IntOffset`), not `Dp`.

## `padding` Internals

Layout modifier — reduces constraints passed to child, expands parent's measured size. Order relative to `size`/`fillMaxWidth` changes which dimension includes padding.

## Custom `Layout` Composable

For multi-child layouts without existing primitives. Receives `MeasurePolicy` — full control over measuring and placing multiple children.

## Performance Rules

- Measure each child once per layout pass
- Avoid reading snapshot state in Composition when only position changes — use layout lambda
- Deep modifier chains with layout modifiers: order determines constraint transformations
