# Dialog and BottomSheet hybrids

## Legacy DialogFragment / BottomSheetDialogFragment

### ComposeView in dialog window

```kotlin
class ComposeBottomSheet : BottomSheetDialogFragment() {
    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View = ComposeView(requireContext()).apply {
        setViewCompositionStrategy(
            ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed
        )
        setContent {
            MaterialTheme { SheetContent(onDismiss = { dismiss() }) }
        }
    }
}
```

### Critical checks

- Composition tied to **`viewLifecycleOwner`**, not only `dialog` instance
- Dismiss removes composition — no retained `ComposeView` reference on singleton
- Back press and config change: test state restoration with unique dialog IDs if multiple Compose dialogs

Audit: `INTEROP-DIALOG-NO-LIFECYCLE-OWNER` when `setContent` runs without lifecycle strategy or before owner exists.

## Material Compose Dialog / ModalBottomSheet

During migration you may have:

- Legacy `DialogFragment` on some flows
- `androidx.compose.material3.ModalBottomSheet` on others

**Do not** stack two modal systems for the same user action. Pick one owner per feature.

Compose `Dialog`/`ModalBottomSheet` are fully Compose — use `compose-composition-core` for perf; this reference covers **View-window hosting** only.

## Window insets

Dialog windows have their own decor. Edge-to-edge: apply inset consumption on the dialog root once; avoid Compose and View both adding system bar padding.

## Testing

Use `createAndroidComposeRule` for Activities hosting dialogs; for dialog fragments, fragment scenario tests + idling on composition.

## Related

- [compose-view-in-views.md](compose-view-in-views.md)
- [interop-performance-checklist.md](interop-performance-checklist.md)
