---
name: compose-animations
description: >
  Jetpack Compose animation APIs: animate*AsState, updateTransition, AnimatedVisibility,
  AnimatedContent, Animatable, AnimationSpec, and graphicsLayer lambda for phase-optimal
  animations. Trigger: when implementing animations in Compose, using AnimatedVisibility,
  AnimatedContent, graphicsLayer transforms, or choosing between animation APIs.
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

### Animation Value in Drawing Phase Only

```kotlin
// ❌ Property overload — reads animX in Composition phase
// Every animation frame recomposes the entire composable scope
val animX by animateFloatAsState(targetValue = if (moved) 200f else 0f, label = "SlideX")

Box(
    Modifier
        .graphicsLayer(translationX = animX)  // read in Composition — recomposes every frame
        .size(100.dp)
        .background(Color.Blue)
)

// ✅ Lambda overload — reads animX in Drawing phase only
// Animation frames do NOT trigger recomposition; only Drawing phase runs
Box(
    Modifier
        .graphicsLayer { translationX = animX }  // read in Drawing — zero recompositions
        .size(100.dp)
        .background(Color.Blue)
)
```

The lambda form of `graphicsLayer { }` creates its own draw-phase scope. State reads inside that lambda are invisible to the Composition phase — the composable does not recompose on every animation tick; only the single Drawing node re-runs.

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
- Choosing which animation API to use (`animate*AsState`, `updateTransition`, `Animatable`, etc.)
- Implementing `AnimatedVisibility` or `AnimatedContent` for UI state transitions
- Applying transforms (`translationX`, `scaleX`, `alpha`, `rotation`) in animations
- Animating colors (`background`, custom drawing)
- Building sequential or interruptible animations with `LaunchedEffect` + `Animatable`
- Debugging animation jank or unexpected recompositions during animation
- Configuring `AnimationSpec` (`spring`, `tween`, `keyframes`, `snap`)

---

## When to Use This vs compose-effects

Both this skill and `compose-effects` involve `LaunchedEffect` + `Animatable`. The distinction:

| Scenario | Use |
|----------|-----|
| Choosing the right animation API, phase-optimal rendering, `AnimatedVisibility`, `AnimatedContent`, `animate*AsState`, `CompositingStrategy` | **compose-animations** (this skill) |
| Effect lifecycle, `LaunchedEffect` key rules, `rememberUpdatedState`, `snapshotFlow`, `DisposableEffect`, side effects | **compose-effects** |
| Sequential animations or interruptible animations driven by `LaunchedEffect` + `Animatable.animateTo()` | **Both** — `compose-effects` for the `LaunchedEffect` pattern; this skill for `Animatable` API and phase placement |

When you see `LaunchedEffect` + `Animatable` together, load both skills.

---

## CMP Applicability

> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)

| Source set | Status | Notes |
|------------|--------|-------|
| `commonMain` | ✅ | All animation APIs are commonMain-safe |
| `androidMain` | ✅ | Full skill content applies |
| `iosMain` | ✅ | `animate*AsState`, `Animatable`, `updateTransition`, `AnimatedVisibility`, `AnimatedContent` all supported |
| `desktopMain` | ✅ | Same as above |
| `wasmJsMain` | ✅ | Same as above |

**Status legend**: ✅ fully supported · ⚠️ partial / version-gated · ❌ Android-only.

**If using in CMP**: All animation APIs in this skill (`animate*AsState`, `Animatable`, `updateTransition`, `AnimatedVisibility`, `animateContentSize`, `graphicsLayer` lambda) are `commonMain`-safe. No version gates or platform exclusions apply. See [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md) for general CMP rules.

---

## Critical Patterns

### 1. `graphicsLayer { }` Lambda Overload — ALWAYS

The lambda form reads state only in the Drawing phase, skipping Composition and Layout entirely. The property overload (`graphicsLayer(translationX = value)`) evaluates in Composition and recomposes the scope on every animation frame.

```kotlin
val animAlpha by animateFloatAsState(if (visible) 1f else 0f, label = "FadeAlpha")

// ❌ Forces Composition phase — recomposes every animation tick
Modifier.graphicsLayer(alpha = animAlpha)

// ✅ Drawing phase only — zero recompositions per animation tick
Modifier.graphicsLayer { alpha = animAlpha }
```

This is the single highest-impact animation performance rule. Apply it unconditionally.

### 2. `Modifier.drawBehind` for Animated Colors

`drawBehind { drawRect(animatedColor) }` reads the color only in the Drawing phase. `Modifier.background(animatedColor)` reads during Composition, triggering recomposition on every animation frame.

```kotlin
val animatedColor by animateColorAsState(
    targetValue = if (selected) Color.Blue else Color.Gray,
    label = "SelectionColor"
)

// ❌ background() reads animatedColor in Composition — recomposes every frame
Box(Modifier.background(animatedColor))

// ✅ drawBehind reads animatedColor in Drawing phase only
Box(Modifier.drawBehind { drawRect(animatedColor) })
```

### 3. `CompositingStrategy` Choices

`graphicsLayer { alpha < 1f }` creates an offscreen GPU buffer by default (`Auto`). Avoid when content does not overlap.

| Strategy | Buffer | Use When |
|----------|--------|----------|
| `Auto` (default) | Yes, when `alpha < 1f` | Content overlaps and must composite correctly |
| `ModulateAlpha` | No | Content does NOT overlap (simpler views, icons) |
| `Offscreen` | Yes, always | `BlendMode` isolation required (e.g., `BlendMode.DstIn` for masks) |

```kotlin
// ✅ Non-overlapping content — eliminates GPU offscreen buffer
Modifier.graphicsLayer {
    alpha = 0.5f
    compositingStrategy = CompositingStrategy.ModulateAlpha
}
```

### 4. API Selection Decision Tree

```
Single property changing on state?
  └─ YES → animate*AsState (simplest; handles interruption automatically)

Multiple properties from the same state change?
  └─ YES → updateTransition (synchronized, single state source, all properties move together)

Sequential or interruptible animations?
  └─ YES → Animatable + LaunchedEffect (full coroutine control)

Indefinitely repeating?
  └─ YES → rememberInfiniteTransition (built-in looping)
```

### 5. `AnimatedVisibility` Removes Content After Exit

Content inside `AnimatedVisibility` is fully removed from composition after the exit animation completes — freeing memory and ensuring accessibility services ignore it. Prefer this over manual `alpha` animations that leave invisible-but-present content in the tree.

```kotlin
AnimatedVisibility(
    visible = isVisible,
    enter = fadeIn() + slideInVertically(),
    exit = fadeOut() + slideOutVertically(),
    label = "CardVisibility"
) {
    Card { ... }  // removed from composition after exit animation; not just alpha=0
}
```

### 6. `label` Is MANDATORY on All Animations

Required for Android Studio Animation Preview and systrace identification. Without it, animations appear as unnamed frames in tooling, making debugging impossible.

```kotlin
// ❌ Missing label — invisible in Animation Preview and systrace
val alpha by animateFloatAsState(targetValue = if (visible) 1f else 0f)

// ✅ Named — appears correctly in Animation Preview and systrace
val alpha by animateFloatAsState(
    targetValue = if (visible) 1f else 0f,
    label = "CardAlpha"
)
```

Apply `label` to every `animate*AsState`, `AnimatedVisibility`, `AnimatedContent`, `updateTransition`, and `rememberInfiniteTransition` call.

### 7. `animateContentSize` Position in Modifier Chain

`animateContentSize()` MUST appear BEFORE size modifiers (`height()`, `size()`, `fillMaxWidth()`). Placing it after causes the animation to measure against already-constrained dimensions, producing incorrect layout values and jank.

```kotlin
// ❌ Wrong order — animateContentSize sees only the fixed height, not the natural content size
Modifier
    .height(if (expanded) 200.dp else 80.dp)
    .animateContentSize()

// ✅ Correct order — animateContentSize intercepts before height constrains measurement
Modifier
    .animateContentSize(animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy))
    .height(if (expanded) 200.dp else 80.dp)
```

### 8. `spring` Over `tween` for Interruptible Animations

`spring` is physics-based. It handles mid-flight interruptions gracefully because it resumes from current velocity without duration arithmetic. `tween` has a fixed duration that creates discontinuities when interrupted mid-way (e.g., user taps a button while animation is running).

```kotlin
// ❌ tween — fixed 300ms; creates discontinuity if interrupted at 150ms
animationSpec = tween(durationMillis = 300)

// ✅ spring — physics handles interruption naturally from current velocity
animationSpec = spring(
    dampingRatio = Spring.DampingRatioMediumBouncy,
    stiffness = Spring.StiffnessMedium
)
```

Use `spring` for button presses, gesture-driven animations, and any animation that may be interrupted. Reserve `tween` for purely cosmetic, non-interruptible transitions (e.g., intro animations).

### 9. `AnimatedContent` Lambda Parameter Rule

Always use the lambda parameter inside `AnimatedContent`, never the outer captured variable. Using the outer variable causes composition key mismatches because the outer variable changes before the exit animation completes, leading to animation glitches.

```kotlin
// ❌ Captured variable — outer count changes before exit animation finishes
AnimatedContent(targetState = count, label = "CounterContent") {
    Text(text = count.toString())  // WRONG: uses outer count, not stable target
}

// ✅ Lambda parameter — stable value scoped to this content's lifecycle
AnimatedContent(targetState = count, label = "CounterContent") { targetCount ->
    Text(text = targetCount.toString())  // correct: uses stable scoped value
}
```

### 10. `TextMotion.Animated` for Animated Text

Text transformed via `graphicsLayer` renders incorrectly under scale or rotation without `TextMotion.Animated`. The default text rendering path is optimized for static text and produces artifacts when the transform matrix changes.

```kotlin
// ❌ Default TextMotion — rendering artifacts under scale/rotation transforms
Text(
    text = "Animated",
    modifier = Modifier.graphicsLayer { scaleX = anim.value }
)

// ✅ TextMotion.Animated — correct rendering under graphicsLayer transforms
Text(
    text = "Animated",
    style = TextStyle(textMotion = TextMotion.Animated),
    modifier = Modifier.graphicsLayer { scaleX = anim.value }
)
```

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| `Modifier.graphicsLayer(alpha = anim)` property overload | `Modifier.graphicsLayer { alpha = anim }` lambda | Composition → Drawing only |
| `Modifier.background(animatedColor)` | `Modifier.drawBehind { drawRect(animatedColor) }` | Composition → Drawing only |
| `graphicsLayer { alpha = 0.5f }` with default `CompositingStrategy` | `CompositingStrategy.ModulateAlpha` (non-overlapping) | Eliminates offscreen GPU buffer |
| Missing `label` on animations | Add `label = "AnimName"` to every `animate*AsState` / `AnimatedVisibility` / `AnimatedContent` | Invisible in Animation Preview / systrace |
| `animateContentSize` after `height()` modifier | Move `animateContentSize()` before `height()` in chain | Jank — incorrect layout measurement |
| `AnimatedContent` using outer variable | Use lambda parameter: `{ targetState -> ... }` | Animation glitches, composition key mismatch |
| `tween` for button/gesture animations | `spring()` — physics handles interruption | Discontinuous animation on mid-flight tap |
| Animated text without `TextMotion.Animated` | `TextStyle(textMotion = TextMotion.Animated)` | Incorrect text rendering under transforms |
| `Animatable` inside `LazyColumn` without hoisting | Hoist `remember { Animatable(...) }` outside lazy layout | Re-triggers on every scroll recomposition |

---

## Code Examples

### `animate*AsState` — Single Property

```kotlin
@Composable
fun FadeButton(isEnabled: Boolean) {
    // Animates alpha when isEnabled changes
    val alpha by animateFloatAsState(
        targetValue = if (isEnabled) 1f else 0.4f,
        animationSpec = spring(stiffness = Spring.StiffnessMediumLow),
        label = "ButtonAlpha"
    )
    Button(
        onClick = {},
        enabled = isEnabled,
        modifier = Modifier.graphicsLayer { this.alpha = alpha }  // Drawing phase only
    ) {
        Text("Click")
    }
}
```

### `updateTransition` — Multiple Synchronized Properties

```kotlin
@Composable
fun SelectableCard(isSelected: Boolean) {
    val transition = updateTransition(targetState = isSelected, label = "CardSelection")

    val alpha by transition.animateFloat(label = "CardAlpha") { selected ->
        if (selected) 1f else 0.6f
    }
    val scale by transition.animateFloat(label = "CardScale") { selected ->
        if (selected) 1.05f else 1f
    }

    // Both alpha and scale animate in sync from the same state change
    Card(
        modifier = Modifier.graphicsLayer {
            this.alpha = alpha
            scaleX = scale
            scaleY = scale
        }
    ) { ... }
}
```

### `Animatable` + `LaunchedEffect` — Sequential Animation

```kotlin
@Composable
fun PulseIndicator() {
    val scale = remember { Animatable(1f) }

    LaunchedEffect(Unit) {
        while (true) {
            scale.animateTo(1.2f, spring(stiffness = Spring.StiffnessLow))
            scale.animateTo(1f, spring(stiffness = Spring.StiffnessLow))
        }
    }

    Box(
        Modifier
            .size(24.dp)
            .graphicsLayer { scaleX = scale.value; scaleY = scale.value }
            .background(Color.Red, CircleShape)
    )
}
```

### `AnimatedVisibility` with Enter/Exit

```kotlin
@Composable
fun NotificationBanner(isVisible: Boolean, message: String) {
    AnimatedVisibility(
        visible = isVisible,
        enter = fadeIn(animationSpec = tween(200)) + expandVertically(),
        exit = fadeOut(animationSpec = tween(200)) + shrinkVertically(),
        label = "NotificationBanner"
    ) {
        // Fully removed from composition after exit; not just invisible
        Surface(color = Color(0xFF4CAF50)) {
            Text(message, modifier = Modifier.padding(16.dp))
        }
    }
}
```

### `AnimatedContent` — Content Transitions

```kotlin
@Composable
fun StepCounter(currentStep: Int) {
    AnimatedContent(
        targetState = currentStep,
        transitionSpec = {
            (slideInVertically { it } + fadeIn()) togetherWith
                    (slideOutVertically { -it } + fadeOut())
        },
        label = "StepCounter"
    ) { step ->  // always use the lambda parameter
        Text(
            text = "Step $step",
            style = TextStyle(textMotion = TextMotion.Animated),  // required for text transforms
            fontSize = 32.sp
        )
    }
}
```

### `animateContentSize` — Expanding Card

```kotlin
@Composable
fun ExpandableCard(title: String, body: String) {
    var expanded by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(  // MUST come before any size modifier
                animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy)
            ),
        onClick = { expanded = !expanded }
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(title, fontWeight = FontWeight.Bold)
            if (expanded) {
                Text(body)
            }
        }
    }
}
```

---

## Commands

```bash
# Inspect animation frames in Android Studio
# Open Android Studio → View → Tool Windows → Layout Inspector
# Enable "Show Recomposition Counts" to verify animations stay out of Composition phase

# Generate Compose Compiler Report to detect animated composables with unstable params
./gradlew assembleRelease
grep -i "unstable" build/compose_compiler/*-classes.txt

# Enable reports in build.gradle.kts:
# composeCompiler {
#     reportsDestination = layout.buildDirectory.dir("compose_compiler")
#     metricsDestination = layout.buildDirectory.dir("compose_compiler")
# }

# Profile animation jank — always on release build
./gradlew :app:connectedReleaseAndroidTest  # Macrobenchmark frame timing
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Stability and recomposition rules that affect animated composables |
| `compose-modifier-system` | `../compose-modifier-system/SKILL.md` | `graphicsLayer`, `drawBehind`, `drawWithContent` — the draw-phase primitives animations use |
| `compose-effects` | `../compose-effects/SKILL.md` | `LaunchedEffect` + `Animatable` pattern for sequential/interruptible animations |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/animation-apis.md](references/animation-apis.md) | API selection, labels, AnimatedVisibility |
| [references/graphics-layer-performance.md](references/graphics-layer-performance.md) | Phase-aware animation, `graphicsLayer` lambda |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx
- **Stable APIs**: `animate*AsState`, `updateTransition`, `AnimatedVisibility`, `AnimatedContent`, `Animatable`, `rememberInfiniteTransition`, `AnimationSpec` family, `graphicsLayer { }` lambda, `CompositingStrategy`
- **Notes**: `Crossfade` is still present but `AnimatedContent` is the modern preferred replacement for content transitions. `label` parameter mandatory since Compose 1.4.
- **Review cadence**: Quarterly
