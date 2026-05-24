# Interop performance checklist

Use before merging hybrid migration PRs. **Release builds only** for timing numbers.

## Pre-flight

- [ ] Identified interop direction: Compose-in-View vs View-in-Compose
- [ ] Confirmed `AndroidView` is SDK-required or documented temporary wrapper
- [ ] `ViewCompositionStrategy` matches host (Fragment/Dialog/RV)
- [ ] No Accompanist interop dependencies added

## Composition

- [ ] Layout Inspector: interop node recomposition count acceptable during scroll
- [ ] No heavy allocation in `AndroidView` `update`
- [ ] RecyclerView: `setContent` not called every `onBind`
- [ ] Compiler report: parameters into interop composables stable where possible

## Layout / scroll

- [ ] Single inset consumer at screen root
- [ ] Nested scroll tested on API 29 and latest (if hybrid scroll)
- [ ] ViewPager2 `offscreenPageLimit` justified for Compose pages

## Lifecycle

- [ ] Navigate away / dismiss dialog — no leaked `ComposeView` (LeakCanary)
- [ ] Fragment `onDestroyView` clears binding references
- [ ] Dialog uses `DisposeOnViewTreeLifecycleDestroyed`

## Measurement

- [ ] Macrobenchmark or manual systrace on hybrid **release** screen
- [ ] Compare frame time vs pre-migration baseline (same device)
- [ ] App Baseline Profile includes non-Compose startup path if View-heavy

## Build / size (informational)

Mixed View+Compose may increase APK and build time (see [Compare metrics](https://developer.android.com/develop/ui/compose/migrate/compare-metrics)). Track separately from runtime jank.

## Audit cross-check

If checklist fails, run `compose-audit` for `INTEROP-*` patterns and load `compose-views-interop` for remediation.
