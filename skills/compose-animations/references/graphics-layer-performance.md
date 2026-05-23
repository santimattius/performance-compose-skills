# Graphics Layer Performance

## Core Rule

Animate in **Drawing phase**, not Composition or Layout.

```kotlin
// ✅ Drawing phase — no Composition recomposition per frame
Modifier.graphicsLayer {
    translationX = offsetAnim.value
    alpha = alphaAnim.value
}

// ❌ Layout phase — triggers measure/layout every frame
Modifier.offset(x = offsetAnim.value.dp)

// ❌ Composition — recomposes entire scope every frame
Box(Modifier.size(animatedSize.dp))
```

## `graphicsLayer` Lambda — Always for Animation

Value overloads read during Composition. Lambda overload defers read to Drawing.

Properties animatable via `graphicsLayer` without remeasurement:
- `translationX/Y`, `scaleX/Y`, `rotationX/Y/Z`, `alpha`, `clip`, `shadowElevation`

## Animated Colors

Prefer `drawBehind { drawRect(color) }` over `background(color)` when color animates frequently — confines invalidation to draw phase.

```kotlin
Modifier.drawBehind {
    drawRect(animatedColor)  // Drawing phase
}
```

## `CompositingStrategy.ModulateAlpha`

When animating alpha on content with overlapping children, can reduce layer compositing cost. Verify availability in your Compose BOM version.

## `AnimatedVisibility` + `graphicsLayer`

Combine for enter/exit that only affects transform/alpha — avoids layout work during transition.

## Measurement Before Optimizing

1. Confirm jank in **release/benchmark** build (debug disables compiler opts)
2. Use Layout Inspector recomposition counts
3. Move hot animation reads to `graphicsLayer { }` lambda
4. Re-measure — Composition count should drop to near zero during animation

## Phase Cost Summary

| Approach | Phase triggered per frame |
|----------|--------------------------|
| `graphicsLayer { translationX = ... }` | Drawing only |
| `Modifier.offset { IntOffset(...) }` | Layout |
| `Modifier.offset(x.dp)` | Composition (+ Layout) |
| `Modifier.size(anim.dp)` | Composition + Layout |
