# ViewPager2 interop

## Compose pages inside ViewPager2

Each page often hosts a `ComposeView` or full-screen composable via `FragmentStateAdapter`.

### Lifecycle / memory

- **Off-screen pages** may keep compositions alive depending on `offscreenPageLimit`.
- Default limit keeps adjacent pages composed → memory ∝ page complexity × limit.
- Reduce `offscreenPageLimit` when pages are Compose-heavy (measure memory in release).
- Use **Fragment + `DisposeOnViewTreeLifecycleDestroyed`** per page when pages are Fragments.

### ComposeView in page layout

Same rules as RecyclerView: **do not `setContent` on every page select** — bind state into existing composition.

```kotlin
// Page Fragment
override fun onCreateView(...): View =
    ComposeView(requireContext()).apply {
        setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
        )
        setContent {
            val pageIndex = rememberPageIndex() // from arguments / ViewModel
            MaterialTheme { PageContent(pageIndex) }
        }
    }
```

Audit: `INTEROP-VIEWPAGER2-OFFSCREEN-COMPOSE` when limit is high and pages allocate heavily without disposal strategy.

## ViewPager2 with legacy View pages + one Compose page

- Treat Compose page as Fragment or dedicated ViewHolder pattern above.
- Keep **theme** consistent (`MaterialTheme` matches Activity theme).

## Nested scrolling

ViewPager2 + vertically scrolling Compose (`LazyColumn`) requires careful nested scroll dispatch. Prefer:

- Horizontal pager + vertical lazy list with standard nested scroll modifiers, or
- Full Compose `HorizontalPager` when migration allows (pure Compose — not interop skill primary path).

## androidx only

Use `androidx.viewpager2.widget.ViewPager2` — no Accompanist Pager in this skill.

## Nav3 follow-up

Replacing ViewPager2 + Fragment pages with `NavDisplay` and scene strategies is documented in `compose-navigation-nav3` — out of v1 for this skill.

## Related

- [recycler-view-interop.md](recycler-view-interop.md) (ViewPager2 uses RV internally)
- [single-activity-fragments.md](single-activity-fragments.md)
