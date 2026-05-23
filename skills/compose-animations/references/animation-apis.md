# Animation APIs

## API Selection Decision Tree

```
Animating a single property on enter/exit visibility?
└── AnimatedVisibility (+ optional animateEnterExit on child)

Animating one property to a target value?
└── animate*AsState (Float, Dp, Color, etc.)

Multiple related properties in sync?
└── updateTransition + animateFloat/Dp/Color in transition scope

Precise control, interruptible, gesture-driven?
└── Animatable + coroutine (animateTo, snapTo)

Container size change animation?
└── animateContentSize (position-only — no scale distortion)
```

## Mandatory `label` Parameter

All animations require `label` since Compose 1.4 — enables debugging in Layout Inspector and Studio.

```kotlin
animateFloatAsState(target, label = "fade")
infiniteRepeatable(tween(300), label = "pulse")
```

## Spec Preference

Prefer `spring()` over `tween()` for natural motion unless timing must be exact.

## `AnimatedVisibility`

- Removes from composition when hidden (saves layout/draw cost)
- Respects accessibility — hidden content not focusable
- Use `Modifier.animateEnterExit()` for child-specific enter/exit within visibility

## `animateContentSize`

Animates size changes only — does NOT scale content. Good for expanding/collapsing sections without distortion.

## `updateTransition`

Centralizes multiple animated values driven by a single state (e.g., `ButtonState.Pressed` → animate color, elevation, scale together).

## Anti-Patterns

| Pattern | Fix |
|---------|-----|
| Animating layout properties (`Modifier.size(anim.dp)`) | `graphicsLayer { scaleX/Y }` or `translationX/Y` |
| Missing `label` | Add descriptive label string |
| `tween` everywhere | `spring` for interactive UI |
| Animating alpha without compositing strategy on complex trees | See graphics-layer-performance.md |
