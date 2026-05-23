# MVVM Patterns

## ViewModel State Exposure

```kotlin
class CoursesViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(CoursesUiState())
    val uiState: StateFlow<CoursesUiState> = _uiState.asStateFlow()

    fun onAction(action: CoursesAction) { ... }
}
```

Expose **immutable** `StateFlow` — never expose `MutableStateFlow`.

## Collecting in Compose

```kotlin
val uiState by viewModel.uiState.collectAsStateWithLifecycle()
```

Requires `lifecycle-runtime-compose` artifact. **Non-optional** for production — lifecycle-aware collection stops when not STARTED.

Never use bare `collectAsState()` in Android production screens.

## `stateIn` for Derived Flows

```kotlin
val uiState: StateFlow<UiState> = repository.observe()
    .map { ... }
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UiState.Loading,
    )
```

`WhileSubscribed(5_000)` stops upstream when no collectors for 5s — saves resources.

## UiState Design

- Single data class per screen (or sealed hierarchy for distinct modes)
- Mark stable: all `val`, stable property types, `@Immutable` on data classes
- Use `ImmutableList` for collections

```kotlin
@Immutable
data class CoursesUiState(
    val courses: ImmutableList<CourseUi> = persistentListOf(),
    val loading: Boolean = false,
    val error: String? = null,
)
```

## Events as State (Preferred over Channels)

Model one-shot UI effects as state fields consumed by Screen:

```kotlin
data class UiState(val snackbarMessage: String? = null, ...)

// ViewModel sets message; Screen shows and clears via action
fun onSnackbarShown() { _uiState.update { it.copy(snackbarMessage = null) } }
```

Avoid `Channel<UiEvent>` / `SharedFlow` one-shots unless legacy constraint.

## UiAction Pattern

```kotlin
sealed interface CoursesAction {
    data class BookmarkClicked(val id: String) : CoursesAction
    data object RetryClicked : CoursesAction
}

fun onAction(action: CoursesAction) = when (action) { ... }
```

Single entry point simplifies testing and logging.

## `_uiState.update { }` vs `.value = .value.copy()`

Prefer `.update { }` for atomic read-modify-write under concurrency.

## `@Stable` for Component State Holders

Complex reusable components extract behavior into `@Stable` state holder classes backed by snapshot state — see compose-composition-core references.

## ViewModel Scoping

- Screen ViewModel: `viewModel()` in Screen composable
- Nav3 destinations: requires `rememberViewModelStoreNavEntryDecorator` — see compose-navigation-nav3 skill
