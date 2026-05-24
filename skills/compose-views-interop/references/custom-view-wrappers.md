# Custom View and View design system wrappers

## Strategy (performance-first)

1. **Short term**: `AndroidView` with fixed size and minimal `update` for charts, calendars, legacy DS widgets.
2. **Medium term**: rewrite simplest widgets to Compose in design-system module.
3. **Long term**: remove View DS dependency on that screen.

Official guidance: use `AndroidView` only for missing SDK support; **rewrite custom Views in Compose** when possible.

## Wrapping custom Views

```kotlin
@Composable
fun LegacyChart(
    data: ChartData,
    modifier: Modifier = Modifier,
) {
    AndroidView(
        modifier = modifier
            .fillMaxWidth()
            .height(200.dp), // fixed height reduces measure churn
        factory = { context ->
            LegacyChartView(context).apply {
                isClickable = true
            }
        },
        update = { chart ->
            if (chart.tag != data.version) {
                chart.setData(data.points)
                chart.tag = data.version
            }
        },
    )
}
```

## View design system (Material Views)

- Theme alignment: map `MaterialTheme` colors to View theme attrs when siblings render in same hierarchy.
- Do not nest heavy DS View subtrees inside every list item without recycling — prefer Compose DS equivalents for lists.

## Semantics

Bridge accessibility: `Modifier.semantics { }` on wrapper; or enable semantics on View via `ViewCompat.setAccessibilityDelegate` in `factory`.

For deep trees, see `compose-quality` (`mergeDescendants`, custom actions).

## Testing

Screenshot test Compose wrapper; View unit tests for custom View logic in isolation.

## Audit

Unnecessary `AndroidView` around composable-replaceable UI → `INTEROP-ANDROIDVIEW-UNNECESSARY` (suggestion).

## Related

- [android-view-in-compose.md](android-view-in-compose.md)
