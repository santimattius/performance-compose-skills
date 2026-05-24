# Single Activity + Fragments

## Topology

One `ComponentActivity` hosts `FragmentContainerView` / `NavHostFragment` with many Fragments; some screens add `ComposeView` incrementally.

## Rules

1. **ViewModel scope**: screen-level `ViewModel` at Fragment destination or Activity — never pass `ViewModel` into deep child composables (see `compose-architecture`).
2. **`viewLifecycleOwner`**: collect UI state with `collectAsStateWithLifecycle()` in `setContent` using `viewLifecycleOwner.lifecycle`.
3. **`onDestroyView`**: composition disposed when strategy is `DisposeOnViewTreeLifecycleDestroyed` — do not hold binding past `onDestroyView`.

```kotlin
class LegacyFragment : Fragment() {
    private var _binding: FragmentBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(...): View {
        _binding = FragmentBinding.inflate(inflater, container, false)
        binding.composeHost.apply {
            setViewCompositionStrategy(
                ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
            )
            setContent {
                val state by viewModel.uiState.collectAsStateWithLifecycle()
                MaterialTheme { LegacyScreenContent(state, viewModel::onAction) }
            }
        }
        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
```

## Back stack

- Replacing Fragment should dispose Compose composition when view hierarchy is destroyed.
- Avoid static references to `ComposeView` from previous Fragment.

## Shared state View ↔ Compose

Prefer **Activity-scoped or nav-scoped ViewModel** as single source; Fragment passes callbacks into `setContent`.

## Navigation

Fragment-based Navigation Component remains valid during migration. Nav3 / Compose navigation is a separate migration (`compose-navigation-nav3`).

## Related

- [compose-view-in-views.md](compose-view-in-views.md)
- [view-binding-bridge.md](view-binding-bridge.md)
