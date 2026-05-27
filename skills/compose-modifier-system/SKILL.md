---
name: compose-modifier-system
description: >
  Jetpack Compose modifier system: modifier order semantics, ModifierNodeElement,
  custom Modifier.Node, layout phase internals, and the three drawing tiers (drawBehind,
  drawWithContent, drawWithCache). Trigger: when creating custom modifiers, working with
  modifier order, custom layout measurement, or draw-phase effects (graphicsLayer, drawBehind).
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

### Lambda Overload vs Value Overload for Modifiers

```kotlin
// Scroll state that changes on every frame
val scrollState = rememberScrollState()

// ❌ Value overload — reads scrollState.value during Composition
// Every scroll tick recomposes the entire composable scope
Box(
    Modifier
        .offset(x = 0.dp, y = scrollState.value.dp)  // read in Composition
        .size(100.dp)
        .background(Color.Blue)
)

// ✅ Lambda overload — reads scrollState.value during Layout phase only
// Scroll ticks do NOT trigger recomposition; Layout phase runs instead
Box(
    Modifier
        .offset { IntOffset(x = 0, y = scrollState.value) }  // read in Layout
        .size(100.dp)
        .background(Color.Blue)
)
```

The lambda form of `offset { }` creates its own layout-phase scope. State reads inside that lambda are invisible to the Composition phase — the composable does not recompose on scroll; only the layout subtree re-runs.

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
- Creating a custom modifier that draws (backgrounds, badges, shimmer, overlays)
- Creating a custom modifier that changes layout (custom padding, placement, sizing)
- Debugging why a modifier is re-running on every recomposition
- Deciding which drawing tier to use (`drawBehind`, `drawWithContent`, `drawWithCache`)
- Working with `Modifier.graphicsLayer { }` for transforms or alpha
- Implementing `ModifierNodeElement` + `Modifier.Node` to replace legacy `Modifier.composed`
- Encountering a runtime crash related to measuring a child twice

---

## CMP Applicability

> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)

| Source set | Status | Notes |
|------------|--------|-------|
| `commonMain` | ✅ | All modifier APIs are commonMain-safe |
| `androidMain` | ✅ | Full skill content applies |
| `iosMain` | ✅ | `graphicsLayer`, `drawBehind`, `Modifier.Node`, `ModifierNodeElement` all supported |
| `desktopMain` | ✅ | Same as above |
| `wasmJsMain` | ✅ | Same as above |

**Status legend**: ✅ fully supported · ⚠️ partial / version-gated · ❌ Android-only.

**If using in CMP**: `graphicsLayer`, `drawBehind`, `Modifier.layout`, and `ModifierNodeElement` are all `commonMain`-safe. Custom draw modifiers using `Canvas` (Compose) APIs work on all CMP targets. Verify `graphicsLayer` lambda overload availability in your CMP version (`CMP 1.6+`). See [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md).

---

## Critical Patterns

### 1. `Modifier.composed` Is DEPRECATED — Use `ModifierNodeElement` + `Modifier.Node`

`Modifier.composed` was the old way to create stateful or composable-aware modifiers. It is DEPRECATED because it allocates a new modifier on every recomposition and cannot be skipped by the Compose compiler.

```kotlin
// ❌ DEPRECATED — allocates on every recompose, cannot skip
fun Modifier.fade(enable: Boolean): Modifier = composed {
    val alpha by animateFloatAsState(if (enable) 0.5f else 1.0f)
    this.graphicsLayer { this.alpha = alpha }
}

// ✅ CORRECT — ModifierNodeElement + Modifier.Node; no allocation on recompose
fun Modifier.circleBackground(color: Color) = this then CircleElement(color)

private data class CircleElement(val color: Color) : ModifierNodeElement<CircleNode>() {
    override fun create() = CircleNode(color)
    override fun update(node: CircleNode) { node.color = color }
}

private class CircleNode(var color: Color) : DrawModifierNode, Modifier.Node() {
    override fun ContentDrawScope.draw() {
        drawCircle(color)
        drawContent()
    }
}
```

For simple cases that only need `CompositionLocal` access or animation state, a `@Composable` factory function is the preferred lightweight alternative to `Modifier.composed`.

### 2. `ModifierNodeElement` MUST Be a `data class`

`equals()` / `hashCode()` correctness on `ModifierNodeElement` determines when `update()` is called vs. when a node is recreated. Without `data class` semantics, the node calls `update()` on every recomposition regardless of whether inputs changed.

```kotlin
// ❌ Missing data class — update() fires every recomposition even with same color
private class CircleElement(val color: Color) : ModifierNodeElement<CircleNode>() { ... }

// ✅ data class — equals/hashCode are auto-generated; update() only fires when color changes
private data class CircleElement(val color: Color) : ModifierNodeElement<CircleNode>() { ... }
```

### 3. `shouldAutoInvalidate = false` for Fine-Grained Invalidation

By default, `Modifier.Node` auto-invalidates (redraws + re-measures) when `update()` is called. Override `shouldAutoInvalidate = false` and call targeted invalidation methods to avoid unnecessary work.

```kotlin
private class OffsetNode(var x: Dp, var y: Dp) : LayoutModifierNode, Modifier.Node() {

    override val shouldAutoInvalidate: Boolean = false  // take control

    fun update(x: Dp, y: Dp) {
        if (this.x != x || this.y != y) invalidatePlacement()  // layout only — no redraw
        this.x = x
        this.y = y
    }

    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints): MeasureResult {
        val placeable = measurable.measure(constraints)
        return layout(placeable.width, placeable.height) {
            placeable.placeRelative(x.roundToPx(), y.roundToPx())
        }
    }
}
```

Use `invalidateDraw()` for draw-only changes, `invalidateMeasurement()` for size changes, and `invalidatePlacement()` for position-only changes.

### 4. Three Drawing Tiers — Decision Tree

| Need | Use | Why |
|------|-----|-----|
| Static background / simple shape | `drawBehind` | Lowest overhead; always draws behind content |
| Full control of draw order relative to content | `drawWithContent` | Can draw before AND after `drawContent()` |
| Expensive objects reused across frames (`Brush`, `Shader`, `Path`) | `drawWithCache` | Cache invalidates on size or read-state change only |

```kotlin
// Tier 1 — drawBehind: static gradient background
Modifier.drawBehind {
    drawRect(Color.LightGray)
}

// Tier 2 — drawWithContent: overlay after content
Modifier.drawWithContent {
    drawContent()
    drawRect(Color.Black.copy(alpha = 0.3f))  // dimmer overlay on top
}

// Tier 3 — drawWithCache: expensive Brush created once, reused every frame
Modifier.drawWithCache {
    // onBuildDrawCache block — runs only when size or observed state changes
    val brush = Brush.linearGradient(
        colors = listOf(Color.Red, Color.Blue),
        start = Offset.Zero,
        end = Offset(size.width, size.height)
    )
    onDrawBehind {
        drawRect(brush)  // brush reused from cache — no allocation per frame
    }
}
```

### 5. `graphicsLayer { }` Lambda — ALWAYS Use the Lambda Overload

The property overload reads state during Composition. The lambda overload reads state during Drawing only.

```kotlin
val animAlpha by animateFloatAsState(if (visible) 1f else 0f)

// ❌ Property overload — reads animAlpha in Composition phase; recomposes on every frame
Modifier.graphicsLayer(alpha = animAlpha)

// ✅ Lambda overload — reads animAlpha in Drawing phase only; zero recompositions
Modifier.graphicsLayer { alpha = animAlpha }
```

### 6. `CompositingStrategy` Choices

`graphicsLayer { alpha < 1f }` creates an offscreen GPU buffer by default (`Auto`). Avoid when content does not overlap.

| Strategy | Buffer | Use When |
|----------|--------|----------|
| `Auto` (default) | Yes, when `alpha < 1f` | Content overlaps and must composite correctly |
| `ModulateAlpha` | No | Content does NOT overlap (simpler views, icons) |
| `Offscreen` | Yes, always | BlendMode isolation is required (e.g., `BlendMode.DstIn` for masks) |

```kotlin
// ✅ Non-overlapping content — skip GPU buffer
Modifier.graphicsLayer {
    alpha = 0.5f
    compositingStrategy = CompositingStrategy.ModulateAlpha
}
```

### 7. Single-Pass Measurement Rule

Compose enforces that each child is measured EXACTLY ONCE per layout pass. Measuring a child twice throws a runtime exception in debug builds.

```kotlin
// ❌ Runtime crash — measurable.measure() called twice
Layout(content = content) { measurables, constraints ->
    val size = measurables[0].measure(constraints)   // first measure
    val real = measurables[0].measure(constraints)   // CRASH: already measured
    layout(real.width, real.height) { real.place(0, 0) }
}

// ✅ Use intrinsics for pre-measurement queries — separate pass, not re-measurement
val minWidth = measurables[0].minIntrinsicWidth(constraints.maxHeight)
val placeable = measurables[0].measure(constraints)
```

Use intrinsics only when strictly necessary — they add a separate measurement pass.

### 8. Coordinates Are Pixels, Not Dp

All draw and layout operations inside `DrawScope`, `MeasureScope`, and placement blocks use pixel units. Always convert.

```kotlin
// ❌ Wrong — Dp passed where pixels are expected
drawCircle(color = Color.Red, radius = 24.dp)

// ✅ Convert using the Density receiver available in DrawScope / MeasureScope
drawCircle(color = Color.Red, radius = 24.dp.toPx())

// ✅ Or use density explicitly when outside a receiver scope
with(density) { 24.dp.toPx() }
```

### 9. Modifier Order Is Semantically Significant

Modifiers are decorators. Each modifier wraps everything below it in the chain. The chain reads left-to-right; outer modifiers wrap inner ones.

```kotlin
// background BEFORE padding — background fills the outer (larger) area
Modifier
    .background(Color.Red)   // draws behind padding + content
    .padding(16.dp)          // content area shrinks inward
    .background(Color.Blue)  // draws behind content only

// clickable BEFORE padding — click target includes the padded area
Modifier
    .clickable { }
    .padding(24.dp)
// vs.
// clickable AFTER padding — click target is only the inner content, not the padding
Modifier
    .padding(24.dp)
    .clickable { }
```

Convention: always place the external `modifier` parameter FIRST on the UI root element, so callers can wrap the entire component.

```kotlin
// ✅ Correct — caller's modifier wraps everything
@Composable
fun UserImage(image: String, modifier: Modifier = Modifier) {
    AsyncImage(
        model = image,
        contentDescription = null,
        modifier = modifier        // caller modifier first
            .size(48.dp)
            .clip(CircleShape)
    )
}
```

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| `Modifier.composed { }` for custom modifier | `ModifierNodeElement` + `Modifier.Node` | Composition (allocates every recompose, can't skip) |
| `ModifierNodeElement` without `data class` | Make it a `data class` — `equals`/`hashCode` gates `update()` | Wasted `update()` calls on every recomposition |
| `Modifier.graphicsLayer(alpha = anim)` property overload | `Modifier.graphicsLayer { alpha = anim }` lambda | Composition → Drawing only |
| `graphicsLayer { alpha = 0.5f }` without `CompositingStrategy` | `CompositingStrategy.ModulateAlpha` (non-overlapping) | GPU offscreen buffer memory |
| `drawWithCache` without expensive objects | `drawBehind` — no caching needed | Unnecessary lambda allocation |
| `Modifier.drawBehind { drawRect(Brush.linearGradient(...)) }` | Move `Brush` creation into `drawWithCache { }` | Brush allocation every draw frame |
| Measuring a child twice in custom layout | Read intrinsics instead, or restructure logic | Runtime crash in debug |
| Using dp values directly in draw operations | Convert with `density.run { xDp.toPx() }` | Wrong pixel coordinates |

---

## Code Examples

### Full Custom Drawing Modifier (ModifierNodeElement Pattern)

```kotlin
// Factory function
fun Modifier.circleBackground(color: Color) = this then CircleBackgroundElement(color)

// Modifier node element — data class for correct equals/hashCode
private data class CircleBackgroundElement(
    val color: Color
) : ModifierNodeElement<CircleBackgroundNode>() {
    override fun create() = CircleBackgroundNode(color)
    override fun update(node: CircleBackgroundNode) { node.color = color }

    override fun InspectorInfo.inspectableProperties() {
        name = "circleBackground"
        properties["color"] = color
    }
}

// Modifier node — implements DrawModifierNode
private class CircleBackgroundNode(var color: Color) : DrawModifierNode, Modifier.Node() {
    override fun ContentDrawScope.draw() {
        drawCircle(color)   // drawn behind content
        drawContent()
    }
}
```

### Custom Layout Modifier

```kotlin
// Reproduces Modifier.padding(all) using layout modifier
fun Modifier.customPadding(all: Dp) = layout { measurable, constraints ->
    val padding = all.roundToPx()
    val placeable = measurable.measure(
        constraints.offset(-padding * 2, -padding * 2)  // shrink constraints
    )
    val width = constraints.constrainWidth(placeable.width + padding * 2)
    val height = constraints.constrainHeight(placeable.height + padding * 2)
    layout(width, height) {
        placeable.placeRelative(padding, padding)
    }
}
```

### drawWithCache — Gradient Reused Across Frames

```kotlin
fun Modifier.animatedGradientBackground(colors: List<Color>) =
    drawWithCache {
        // Brush is created once per size change, not every draw call
        val brush = Brush.linearGradient(
            colors = colors,
            start = Offset.Zero,
            end = Offset(size.width, size.height)
        )
        onDrawBehind {
            drawRect(brush)
        }
    }
```

### @Composable Modifier Factory (Lightweight Alternative to composed)

```kotlin
// Use when modifier needs animation state or CompositionLocal — simpler than ModifierNodeElement
@Composable
fun Modifier.fade(enabled: Boolean): Modifier {
    val alpha by animateFloatAsState(if (enabled) 0.5f else 1.0f)
    return graphicsLayer { this.alpha = alpha }
}
```

### Custom Layout Component

```kotlin
@Composable
fun SimpleRow(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Layout(modifier = modifier, content = content) { measurables, constraints ->
        var widthLeft = constraints.maxWidth
        val placeables = measurables.map { measurable ->
            measurable.measure(
                Constraints(
                    minWidth = 0, minHeight = 0,
                    maxWidth = widthLeft, maxHeight = constraints.maxHeight
                )
            ).also { widthLeft = (widthLeft - it.width).coerceAtLeast(0) }
        }
        val height = (placeables.maxOfOrNull { it.height } ?: 0)
            .coerceIn(constraints.minHeight, constraints.maxHeight)
        val width = placeables.sumOf { it.width }
            .coerceIn(constraints.minWidth, constraints.maxWidth)
        layout(width, height) {
            var xPosition = 0
            placeables.forEach { placeable ->
                placeable.placeRelative(x = xPosition, y = 0)
                xPosition += placeable.width
            }
        }
    }
}
```

---

## Commands

```bash
# Generate compiler stability report to check modifier stability
./gradlew assembleRelease  # then check build/compose_compiler/

# Enable reports in build.gradle.kts:
# composeCompiler {
#     reportsDestination = layout.buildDirectory.dir("compose_compiler")
#     metricsDestination = layout.buildDirectory.dir("compose_compiler")
# }

# Check for unstable modifier elements introduced in a PR
grep "unstable" build/compose_compiler/*-classes.txt
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Underlying recomposition and stability rules that govern when modifiers re-run |
| `compose-animations` | `../compose-animations/SKILL.md` | `graphicsLayer { }` lambda used to animate transforms in Drawing phase only |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/modifier-fundamentals.md](references/modifier-fundamentals.md) | Decorator model, order, `modifier` convention |
| [references/custom-modifier-nodes.md](references/custom-modifier-nodes.md) | `ModifierNodeElement`, composable factories |
| [references/layout-phase.md](references/layout-phase.md) | Layout phase, `offset` lambda overload |
| [references/drawing-phase.md](references/drawing-phase.md) | Draw tiers, `graphicsLayer` lambda |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx
- **Stable APIs**: `ModifierNodeElement`, `Modifier.Node`, `drawBehind`, `drawWithContent`, `drawWithCache`, `graphicsLayer { }` lambda, `Layout`, `MeasurePolicy`
- **Deprecated**: `Modifier.composed {}` — deprecated, not recommended; replace with `ModifierNodeElement` + `Modifier.Node`
- **Review cadence**: Quarterly
