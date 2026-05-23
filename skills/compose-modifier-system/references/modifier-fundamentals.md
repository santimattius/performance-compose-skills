# Modifier Fundamentals

## Modifiers Are Decorators, Not Properties

Modifiers wrap components in order. The **first** modifier in the chain is the outermost wrapper. Components are ultimately modifiers + `Layout`.

```
Modifier.padding(8.dp).background(Red).size(100.dp)
// Outermost: padding → background → size → content
```

## Order Matters

`padding` then `background` ≠ `background` then `padding`. Drawing and layout modifiers interact — wrong order changes visible bounds and hit targets.

## `modifier` Parameter Convention

- First optional parameter: `modifier: Modifier = Modifier`
- Applied at the **UI root** of the component (outermost wrapper)

```kotlin
@Composable
fun Badge(count: Int, modifier: Modifier = Modifier) {
    Surface(modifier = modifier) { ... }  // ✅ at root
}
```

## Chaining Rules

Always extend the chain from `this`:

```kotlin
fun Modifier.optionalPadding(enable: Boolean, all: Dp) =
    if (enable) this.padding(all) else this  // ✅

fun Modifier.broken(enable: Boolean, all: Dp) =
    if (enable) Modifier.padding(all) else this  // ❌ drops previous modifiers
```

Use `then` when applying a stored `Modifier` variable: `this then storedModifier`.

## Built-in Modifier Categories by Phase

| Phase | Examples |
|-------|----------|
| Layout | `size`, `padding`, `offset`, `fillMaxSize`, `layout { }` |
| Drawing | `background`, `border`, `drawBehind`, `drawWithContent`, `graphicsLayer` |
| Composition | `clickable`, `pointerInput`, semantics |

## Performance: Lambda Overloads

For rapidly changing values (scroll, animation), prefer lambda overloads to confine reads to Layout/Drawing:

```kotlin
Modifier.offset { IntOffset(0, scrollPx) }  // ✅ Layout phase read
Modifier.offset(0.dp, scrollDp)               // ❌ Composition read
Modifier.graphicsLayer { translationX = anim } // ✅ Drawing phase
```

## Single-Pass Measurement

Custom layout modifiers must measure children at most once per pass. Remeasurement is expensive — design modifiers to avoid invalidating parent constraints unnecessarily.
