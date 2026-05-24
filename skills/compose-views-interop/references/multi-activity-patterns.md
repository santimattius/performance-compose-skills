# Multi-Activity patterns

## When this applies

Legacy apps launch new Activities per feature; new flows use `ComponentActivity.setContent` while old flows remain XML/Fragment.

## One composition root per Activity

| Pattern | Composition root |
|---------|------------------|
| New Compose Activity | `setContent { }` on `onCreate` |
| Legacy XML Activity | Optional `ComposeView` islands — each is a root |
| Compose Activity + no XML | Single root — preferred for new screens |

**Anti-pattern**: multiple independent `setContent` calls on the same Activity without a single theme/root composable.

## Transitions

- Pass **IDs / lightweight args** via Intent — not large parcels of UI state.
- Restore theme: `MaterialTheme` color scheme should match Activity theme to avoid flash.
- Shared `ViewModel` across Activities only via explicit scope (navigation graph, shared repository) — not static singletons for UI state.

## setContent vs ComposeView in Activity

```kotlin
// Preferred new screen
class NewFlowActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AppTheme { NewFlowRoot() }
        }
    }
}

// Legacy Activity adding island
class OldActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.old)
        findViewById<ComposeView>(R.id.compose_panel).setContent {
            AppTheme { PanelContent() }
        }
    }
}
```

## Performance

- Each Activity transition pays Activity creation cost; interop does not remove that.
- Prefer single-Activity long-term — multi-Activity interop is **coexistence**, not target architecture.

## Related

- [compose-view-in-views.md](compose-view-in-views.md)
- [interop-performance-checklist.md](interop-performance-checklist.md)
