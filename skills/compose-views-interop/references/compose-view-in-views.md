# ComposeView in Views

## APIs

- `ComposeView` / `AbstractComposeView` — `setContent { }` installs a composition
- `ViewCompositionStrategy` — **when** the composition is disposed

## Strategy matrix (androidx)

| Strategy | Dispose when | Use for |
|----------|--------------|---------|
| `DisposeOnDetachedFromWindowOrReleasedFromPool` (**default**) | Detach or RV pool discard | `ComposeView` in lists, mixed screens |
| `DisposeOnViewTreeLifecycleDestroyed` | Host `LifecycleOwner` destroyed | **Fragment**, **Dialog** |
| `DisposeOnLifecycleDestroyed(lifecycle)` | Given lifecycle ends | Explicit lifecycle you hold |
| `DisposeOnDetachedFromWindow` | Detach only | Legacy; prefer pool-aware default |

### Fragment (critical)

```kotlin
override fun onCreateView(...): View {
    return ComposeView(requireContext()).apply {
        setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
        )
        setContent {
            MaterialTheme { FeatureContent() }
        }
    }
}
```

Using **default** in Fragments often loses state on `onDestroyView` or retains composition too long.

## Activity patterns

**Compose-only screen**: `ComponentActivity.setContent { }` — no `ComposeView` needed.

**XML + Compose island**:

```xml
<androidx.compose.ui.platform.ComposeView
    android:id="@+id/compose_section"
    android:layout_width="match_parent"
    android:layout_height="wrap_content" />
```

```kotlin
binding.composeSection.setContent {
    MaterialTheme { SectionContent() }
}
```

## Multiple ComposeViews

Each `ComposeView` in the same layout needs a **unique `android:id`** for `savedInstanceState`.

## Window insets

Default: each `ComposeView` consumes insets at `WindowInsetsCompat` level.

Hybrid root is a **ViewGroup**: consume insets once at View root; consider `consumeWindowInsets = false` on child `ComposeView` to avoid double padding.

## Insets doc

[Insets for Views + Compose](https://developer.android.com/develop/ui/compose/system/insets-views-compose)

## Anti-patterns

| Pattern | Risk |
|---------|------|
| `setContent` before lifecycle STARTED | Crash or leak |
| Recreating `ComposeView` on config change without id | State loss |
| Fragment without lifecycle strategy | Critical — audit `INTEROP-COMPOSEVIEW-WRONG-STRATEGY` |

## Related

- [single-activity-fragments.md](single-activity-fragments.md)
- [dialog-bottomsheet-hybrids.md](dialog-bottomsheet-hybrids.md)
- [recycler-view-interop.md](recycler-view-interop.md)
