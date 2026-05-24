# AndroidView in Compose

## When to use

Use `AndroidView` **only** when the Android SDK (or a required binary SDK) has no Compose equivalent:

- `MapView`, `WebView`, `AdView`, camera preview surfaces, legacy proprietary SDK widgets

Do **not** use for `TextView`, `Button`, `RecyclerView` rows you could model in Compose, or internal custom widgets you plan to rewrite.

## Performance model

- `factory` runs when the `View` is first created.
- **`update` runs on every recomposition** where a `State` read inside `update` changed.
- Work in `update` is **Composition-phase cost** — treat it like composable body work.

## Correct pattern

```kotlin
AndroidView(
    modifier = Modifier.fillMaxSize(),
    factory = { context ->
        MapView(context).apply {
            onCreate(null)
            onResume()
        }
    },
    update = { map ->
        // Minimal sync — avoid allocations
        val target = cameraTarget
        if (map.tag != target) {
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(target, 14f))
            map.tag = target
        }
    },
    onRelease = { map ->
        map.onPause()
        map.onDestroy()
    },
)
```

## Rules

1. **Construct in `factory`**, not `remember { View(context) }` outside `AndroidView`.
2. **Diff in `update`** — skip work when inputs unchanged (`tag`, last bound id).
3. **Fixed size** when possible — `Modifier.size` or `fillMaxSize` avoids repeated measure churn.
4. **Dispose in `onRelease`** for SDKs that need explicit teardown.

## LazyColumn / LazyRow (Compose 1.4+)

Use overload with **`onReset` (non-null)** for View reuse:

```kotlin
AndroidView(
    factory = { ctx -> MyWidget(ctx) },
    update = { it.bind(item.id) },
    onReset = { it.unbind() },
    onRelease = { it.dispose() },
)
```

Without `onReset`, scrolling lists recreate or leak View state.

## AndroidViewBinding

- Use for **small legacy XML** snippets during migration.
- Do **not** inflate full screen XML inside Compose-only destinations.
- Dependency: `androidx.compose.ui:ui-viewbinding`

## Anti-patterns

| Pattern | Problem |
|---------|---------|
| `AndroidView` wrapping custom chart you own | Permanent Composition + View double stack |
| Rebuilding View hierarchy in `update` | Recomposition allocates every frame |
| Reading rapidly changing animation state in `update` | Defer to View callback or `graphicsLayer` in pure Compose sibling |

## Related

- [custom-view-wrappers.md](custom-view-wrappers.md)
- [interop-performance-checklist.md](interop-performance-checklist.md)
