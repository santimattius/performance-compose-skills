# Previews and Parameters

## @Preview Basics

- Preview composables in `src/debug/` or dedicated preview source set
- Wrap with app theme — or use `@PreviewWrapper` (April 2026+) for module-wide theme

```kotlin
@Preview(showBackground = true, name = "Light")
@Composable
fun MyButtonPreview() {
    AppTheme { MyButton(text = "Save", onClick = {}) }
}
```

Useful params: `showBackground`, `uiMode`, `fontScale`, `locale`, `device`, `name`.

## @PreviewWrapper — NEW April 2026

> Not present in pre-2026 documentation.

Module-wide theme wrapper — eliminates per-preview theme boilerplate:

```kotlin
class AppThemePreviewWrapper : PreviewWrapperProvider {
    @Composable
    override fun PreviewWrapper(content: @Composable () -> Unit) {
        AppTheme { Surface { content() } }
    }
}

@PreviewWrapper(AppThemePreviewWrapper::class)
annotation class AppPreview

@AppPreview
@Composable
fun MyButtonPreview() { MyButton(...) }
```

## @PreviewParameter

Generates one preview per provider value:

```kotlin
class UserStateProvider : PreviewParameterProvider<UserState> {
    override val values = sequenceOf(Loading, Success("Jane"), Error("Timeout"))
}

@Preview
@Composable
fun UserCardPreview(@PreviewParameter(UserStateProvider::class) state: UserState) {
    UserCard(state = state)
}
```

**Decision:** use for distinct state variants (loading/success/error). Avoid >10 previews per component — degrades IDE performance.

## Preview Content Composables

Preview **Content** composables (stateless) with fake `UiState` — not Screen/ViewModel wiring.

## Layout Inspector (API 29+, Compose 1.2+)

- Recomposition counts per composable
- Semantics tree inspection
- Modifier chain visualization

Enable: Android Studio → View → Tool Windows → Layout Inspector

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Previewing Screen with real ViewModel | Preview Content with sample state |
| Missing theme wrapper | `@PreviewWrapper` or manual theme |
| `@PreviewParameter` with huge cartesian product | Limit provider values |
