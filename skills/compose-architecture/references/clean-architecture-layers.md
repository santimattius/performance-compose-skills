# Clean Architecture Layers

## Where Compose Lives

Compose is a **UI toolkit**, not an architecture. Clean Architecture boundaries unchanged:

```
UI (Compose) → Presentation (ViewModel) → Domain → Data
```

- Domain must NOT depend on Compose, Android UI, Retrofit, Room
- Composables render state and emit events — no business rules, DB, or network calls

## Runtime Flow

- Events: `UI → Presentation → Domain → Data`
- Results: `Data → Domain → Presentation → UI`

## Unidirectional Data Flow

- State flows **down** into composables
- Events flow **up** via callbacks or `UiAction`

```kotlin
@Composable
fun CourseCard(model: CourseUi, onClick: () -> Unit, onBookmarkClick: () -> Unit) { ... }
```

Stateless, reusable, no architecture knowledge.

## Screen / Content Split

| Composable | Responsibility |
|------------|----------------|
| `XxxScreen` (Route/Bridging) | Obtain ViewModel, collect state, handle navigation/effects |
| `XxxScreenContent` | Pure UI from state + action callbacks |

```kotlin
@Composable
fun CoursesScreen(viewModel: CoursesViewModel = viewModel(), onOpenCourse: (String) -> Unit) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    CoursesScreenContent(state = uiState, onAction = viewModel::onAction, onCourseClick = onOpenCourse)
}
```

## Anti-Patterns

| Anti-pattern | Why wrong |
|--------------|-----------|
| Business logic in composable | Untestable, not reusable |
| Passing ViewModel to child composables | Couples UI tree to presentation |
| Reading `StateFlow.value` directly | No recomposition |
| `collectAsState()` without lifecycle | Collects when not visible — leaks/work |
| Channel/SharedFlow for one-shot UI events | Prefer events-as-state in UiState |
| `AndroidViewModel` for new code | Not recommended — use plain `ViewModel` + injected `Application` if needed |

## Hoist High, Read Low

Collect state once at Screen level. Pass narrow slices to Content children — not entire `UiState` unless child needs most fields.

## Testing Boundary

Content composables are previewable and testable with fake state. Screen composables tested with fake ViewModel or integration tests.
