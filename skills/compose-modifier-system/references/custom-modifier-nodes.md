# Custom Modifier Nodes

## Three Implementation Tiers

| Tier | When | Performance |
|------|------|-------------|
| Extension on `Modifier` combining existing modifiers | Simple decoration | Good for most cases |
| `@Composable fun Modifier.xxx()` factory | Needs `remember`, `LocalDensity`, theme | Good for animated/simple stateful modifiers |
| `ModifierNodeElement` + `Modifier.Node` | Production custom modifiers | Best — optimized, invalidation control |

## `Modifier.composed` — DEPRECATED

Do not use `composed { }` for new code. Prefer `@Composable` factory or `ModifierNodeElement`.

```kotlin
// ❌ Deprecated
fun Modifier.fade(enable: Boolean) = composed { ... }

// ✅ Composable factory (simple cases)
@Composable
fun Modifier.fade(enable: Boolean): Modifier {
    val alpha by animateFloatAsState(if (enable) 0.5f else 1f)
    return graphicsLayer { this.alpha = alpha }
}
```

## `ModifierNodeElement` Pattern

```kotlin
fun Modifier.myModifier(param: Float) = this then MyElement(param)

private class MyElement(val param: Float) : ModifierNodeElement<MyNode>() {
    override fun create() = MyNode(param)
    override fun update(node: MyNode) { node.param = param }
    override fun equals(other: Any?) = other is MyElement && other.param == param
    override fun hashCode() = param.hashCode()
}

private class MyNode(var param: Float) : Modifier.Node(), LayoutModifierNode {
    override fun MeasureScope.measure(measurable: Measurable, constraints: Constraints) = ...
}
```

**Rules:**
- Implement `data class`-style `equals`/`hashCode` on the Element
- Set `shouldAutoInvalidate = false` when updates don't require full invalidation
- Separate Element (immutable config) from Node (mutable runtime state)

## `@Composable` Modifier Factories — Common Cases

- `remember { MutableInteractionSource() }` for custom clickable
- `LocalDensity` / `LocalWindowInfo` for responsive sizing
- `MaterialTheme` access for themed drawing

## Composing Modifiers from Modifiers

Many library modifiers are thin wrappers:

```kotlin
fun Modifier.clip(shape: Shape) = graphicsLayer(shape = shape, clip = true)
fun Modifier.alpha(a: Float) = if (a != 1f) graphicsLayer(alpha = a, clip = true) else this
```

Study these before building custom nodes — often an existing modifier suffices.
