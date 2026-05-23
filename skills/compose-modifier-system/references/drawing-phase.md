# Drawing Phase

## Drawing Modifier Hierarchy (prefer top → bottom for performance)

| Tier | API | When |
|------|-----|------|
| 1 — Cheapest | `drawBehind { }` | Simple shapes behind content, animated colors |
| 2 — Flexible | `drawWithContent { drawContent(); ... }` | Draw before AND/OR after content |
| 3 — Cached | `drawWithCache { onDrawBehind { } }` | Expensive path/stroke setup reused across frames |

## Draw Order

Parent draws first, calls `drawContent()` to delegate to children, then draws after:

```
#1 before → #2 before → content → #2 after → #1 after
```

`background` draws before content. `border` draws after content.

## `graphicsLayer` — Always Lambda for Animation

```kotlin
Modifier.graphicsLayer {
    translationX = anim.value
    alpha = anim.value
    clip = true
}
```

Lambda overload reads state in Drawing phase — avoids Composition recomposition on every animation frame.

**Also use for:** clip, rotation, scale, shadow elevation without triggering layout remeasurement.

## Coordinates

- `DrawScope` uses **pixels** — convert with `toPx()` from `Dp`
- `center`, `size` in draw scope are in pixels

## `Canvas` Composable

Alternative to draw modifiers for standalone drawing. Prefer modifiers when decorating existing content.

## `shouldAutoInvalidate`

On custom `DrawModifierNode`, set `shouldAutoInvalidate = false` when property updates don't require redraw — reduces invalidation churn.

## `CompositingStrategy`

Use `CompositingStrategy.ModulateAlpha` when animating alpha on complex content — can reduce overdraw cost. Verify BOM version availability.

## Anti-Patterns

| Pattern | Problem |
|---------|---------|
| `drawWithContent` for simple solid background | Use `drawBehind` or `background` |
| Value-based `graphicsLayer(translationX = anim.value)` | Recomposes Composition every frame |
| Drawing in `@Composable` body without modifier | Wrong phase; use draw modifier |
