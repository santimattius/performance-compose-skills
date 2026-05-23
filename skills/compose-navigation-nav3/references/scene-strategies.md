# Scene Strategies

## Built-in (in Nav3 core artifact)

| Strategy | Use case |
|----------|----------|
| `SinglePaneSceneStrategy()` | Default — one entry visible |
| `rememberListDetailSceneStrategy()` | List + detail panes, adaptive layouts |
| `DialogSceneStrategy<NavKey>()` | Overlay dialogs |

Register multiple strategies chained with `then`:

```kotlin
val listDetail = rememberListDetailSceneStrategy<NavKey>()
val dialog = remember { DialogSceneStrategy<NavKey>() }

NavDisplay(
    sceneStrategy = listDetail then dialog,
    entryProvider = entryProvider {
        entry<AlertKey>(metadata = DialogSceneStrategy.dialog()) {
            AlertDialogContent(onDismiss = navBackStack::removeLastOrNull)
        }
    }
)
```

## Dialog Entries

Requires BOTH:
1. `DialogSceneStrategy` registered on `NavDisplay`
2. `metadata = DialogSceneStrategy.dialog()` on the entry

Navigate: `navBackStack.add(DialogKey)`

## BottomSheetSceneStrategy — NOT in Core

**No built-in bottom sheet strategy.** Copy implementation from Nav3 recipes/samples or implement custom:

1. Custom `OverlayScene` subclass (e.g., `BottomSheetScene`)
2. Custom `SceneStrategy` that creates it
3. Register alongside other strategies
4. Entry metadata marks bottom sheet destinations

```kotlin
entry<SheetKey>(metadata = BottomSheetSceneStrategy.bottomSheet()) {
    SheetContent(onDismiss = navBackStack::removeLastOrNull)
}
```

## OverlayScene Concept

Dialogs and bottom sheets use `OverlayScene` — content below remains visible. Properties:
- `key` — current nav key
- `previousEntries` / `overlaidEntries` — entries visible underneath (predictive back)
- `entries` — entries rendered in this scene
- `content` — composable for the overlay

## Metadata

Entry metadata tells `SceneStrategy` how to render an entry (dialog, bottom sheet, list pane role). Strategies inspect metadata when computing scenes from backstack.

## Multi-Pane

`ListDetailSceneStrategy` adapts to window size — shows one or two panes based on available width. Keys map to list vs detail roles via metadata.

## Pitfalls

| Issue | Fix |
|-------|-----|
| Dialog entry without DialogSceneStrategy registered | Add strategy to `sceneStrategy` chain |
| Expecting BottomSheet in core | Copy from recipes |
| Wrong strategy order | Dialog/overlay strategies typically chained after pane strategy |
