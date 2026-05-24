# compose-views-interop — References

androidx APIs only. Performance-first patterns for hybrid migration.

| File | Load when |
|------|-----------|
| [android-view-in-compose.md](android-view-in-compose.md) | `AndroidView`, SDK widgets, lazy `onReset`/`onRelease` |
| [compose-view-in-views.md](compose-view-in-views.md) | `ComposeView`, `ViewCompositionStrategy`, XML/Activity |
| [recycler-view-interop.md](recycler-view-interop.md) | RecyclerView ViewHolder, Compose in RV, RV in LazyColumn |
| [viewpager2-interop.md](viewpager2-interop.md) | ViewPager2 pages, off-screen Compose |
| [dialog-bottomsheet-hybrids.md](dialog-bottomsheet-hybrids.md) | `DialogFragment`, BottomSheet, Compose overlays |
| [single-activity-fragments.md](single-activity-fragments.md) | Fragment back stack, `viewLifecycleOwner` |
| [multi-activity-patterns.md](multi-activity-patterns.md) | Multiple Activities, `setContent` vs XML |
| [view-binding-bridge.md](view-binding-bridge.md) | ViewBinding layouts with embedded `ComposeView` |
| [custom-view-wrappers.md](custom-view-wrappers.md) | Custom Views, View-based design system widgets |
| [interop-performance-checklist.md](interop-performance-checklist.md) | Verify hybrid screen before/after PR |

Workflow migration (single XML screen): Google's [migrate-xml-views-to-jetpack-compose](https://developer.android.com/agents/skills/jetpack-compose/migration/migrate-xml-views-to-jetpack-compose/skill).
