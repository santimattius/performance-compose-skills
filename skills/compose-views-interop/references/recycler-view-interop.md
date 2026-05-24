# RecyclerView interop

Two directions — pick the doc section for your migration direction.

## A. Compose inside RecyclerView (ViewHolder + ComposeView)

### Pattern

- One `ComposeView` per ViewHolder type (created in `onCreateViewHolder`).
- Call **`setContent` once** in holder init (or first bind), not every `onBindViewHolder`.
- Pass changing data via **state hoisted** into composable parameters (ViewModel, holder `var item` + `setContent` with captured holder — prefer updating via `MutableState` in holder).

```kotlin
class ComposeHolder(view: ComposeView) : RecyclerView.ViewHolder(view) {
    init {
        view.setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnDetachedFromWindowOrReleasedFromPool
        )
        view.setContent {
            val item by holderItemState // MutableState in holder
            MaterialTheme { RowItem(item) }
        }
    }
    fun bind(item: Item) {
        holderItemState.value = item
    }
}
```

### Anti-pattern (critical)

```kotlin
// WRONG — new composition every bind → jank
override fun onBindViewHolder(holder: H, position: Int) {
    (holder.itemView as ComposeView).setContent { ItemRow(items[position]) }
}
```

Audit: `INTEROP-RECYCLERVIEW-RESET-CONTENT`.

### Performance

- Stable `itemId` / `setHasStableIds(true)` when possible.
- Avoid variable-height Compose without measurement hints — causes RV remeasure storms.
- Profile scroll in **release** with Macrobenchmark on the hybrid screen.

## B. RecyclerView inside Compose (AndroidView)

Use when legacy `RecyclerView` cannot be migrated yet.

```kotlin
AndroidView(
    factory = { context ->
        RecyclerView(context).apply {
            layoutManager = LinearLayoutManager(context)
            adapter = legacyAdapter
        }
    },
    update = { rv ->
        // Push diff-friendly updates only when data version changes
        if (rv.tag != dataVersion) {
            legacyAdapter.submitList(items)
            rv.tag = dataVersion
        }
    },
)
```

Prefer migrating to `LazyColumn` when feasible — single layout pass, better skipping.

## C. LazyColumn with AndroidView items

See [android-view-in-compose.md](android-view-in-compose.md) — require `onReset` / `onRelease`.

## Nested scroll

If Compose parent scrolls and RV child scrolls, wire `NestedScrollingConnection` or migrate one axis to a single scroller. Undocumented dual scroll = jank.

## Related

- [compose-view-in-views.md](compose-view-in-views.md)
- [viewpager2-interop.md](viewpager2-interop.md)
