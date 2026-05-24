# ViewBinding bridge

## Pattern

Legacy screen uses ViewBinding; one region migrates to Compose via embedded `ComposeView`.

```xml
<androidx.constraintlayout.widget.ConstraintLayout ...>
    <TextView android:id="@+id/legacy_title" ... />
    <androidx.compose.ui.platform.ComposeView
        android:id="@+id/compose_region"
        android:layout_width="0dp"
        android:layout_height="wrap_content" ... />
</androidx.constraintlayout.widget.ConstraintLayout>
```

```kotlin
class HybridFragment : Fragment() {
    private var _binding: ScreenBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(...): View {
        _binding = ScreenBinding.inflate(inflater, container, false)
        binding.composeRegion.apply {
            setViewCompositionStrategy(
                ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
            )
            setContent {
                MaterialTheme { MigratedRegion(viewModel = viewModel) }
            }
        }
        binding.legacyTitle.text = viewModel.title
        return binding.root
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
```

## Performance

- **Single inflation** per `onCreateView` — do not reinflate binding on recomposition.
- ViewBinding updates for legacy widgets: batch in `onViewCreated` / collectors — not inside Compose.
- Avoid reading binding from composable lambdas — pass plain values/callbacks.

## State bridge

| Direction | Mechanism |
|-----------|-----------|
| View → Compose | ViewModel / `StateFlow` collected in `setContent` |
| Compose → View | ViewModel update observed in Fragment; mutate binding widgets |

Do not mirror the same field in both `TextView.text` and `mutableStateOf` without single owner.

## Related

- [single-activity-fragments.md](single-activity-fragments.md)
- [compose-view-in-views.md](compose-view-in-views.md)
