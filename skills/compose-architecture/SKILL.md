---
name: compose-architecture
description: >
  Jetpack Compose architecture patterns: Clean Architecture layering, MVVM/MVI with
  UiState/UiAction, Screen/Content split, collectAsStateWithLifecycle, stable UI models,
  and ViewModel scoping rules. Trigger: when structuring a Compose screen, wiring a
  ViewModel to UI, choosing MVVM vs MVI, handling UiState/UiAction patterns, or reviewing
  Compose architecture anti-patterns.
license: Apache-2.0
metadata:
  author: Santiago Mattiauda
  version: "1.0"
---

## Performance First

Every Compose frame runs three phases. Cost rises left-to-right; restart scope shrinks left-to-right.

| Phase | What Runs | Restart Cost | Trigger |
|-------|-----------|--------------|---------|
| Composition | Composable functions, state reads | HIGH (whole scope) | State read in composable body |
| Layout | Measure + place | MEDIUM (subtree) | State read in measure lambda |
| Drawing | Canvas commands, graphicsLayer | LOW (single node) | State read in draw/graphicsLayer lambda |

### Defer State Reads (decision tree)

Do you need the value during composition?
- YES → read as `T` (Composition phase) — accept full restart cost
- NO  → can you defer to layout/draw?
  - Layout-only?    → pass `() -> T` into `Modifier.layout`/`offset { }` lambda
  - Draw/transform? → pass `() -> T` into `Modifier.graphicsLayer { }` / `drawBehind { }` lambda

**Rule**: prefer `Modifier.offset { lambda }` over `Modifier.offset(state.value.dp)`. Lambda variant defers the read to the layout phase, skipping recomposition entirely.

### Architecture Impact on Phases — `collectAsStateWithLifecycle` vs `collectAsState`

```kotlin
// CORRECT — lifecycle-aware + stable UiState → composables can skip
@Composable
fun CoursesScreen(viewModel: CoursesViewModel = hiltViewModel()) {
    // collectAsStateWithLifecycle: stops collection when lifecycle is STOPPED
    // (app backgrounded, screen off) — saves CPU and battery
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    CoursesContent(state = uiState, onAction = viewModel::onAction)
}

// Stable UiState: all val properties + ImmutableList → composables are skippable
@Immutable
data class CoursesUiState(
    val isLoading: Boolean = false,
    val courses: ImmutableList<CourseUi> = persistentListOf(), // kotlinx.collections.immutable
    val error: String? = null,
)

// WRONG — collectAsState collects forever AND mutable List makes composables non-skippable
@Composable
fun CoursesScreen(viewModel: CoursesViewModel = hiltViewModel()) {
    // collectAsState: collects even when app is backgrounded → wasted CPU/battery
    val uiState by viewModel.uiState.collectAsState()
    CoursesContent(state = uiState, onAction = viewModel::onAction)
}

// Unstable UiState: var property → whole class inferred unstable → composables never skip
data class CoursesUiState(
    var isLoading: Boolean = false,       // var = UNSTABLE
    val courses: List<CourseUi> = emptyList(), // mutable List = UNSTABLE
)
```

---

## Performance Toolchain

> WARNING: NEVER profile in debug builds. Debug disables R8, inlining, and Strong Skipping — numbers are meaningless. Always profile a release build with `profileable` enabled or a benchmark build type.

| Tool | Use For | When |
|------|---------|------|
| Baseline Profiles | AOT-compile critical paths (startup, scroll) | Ship in release; regenerate per release |
| Compose Compiler Reports | Detect unstable params, restartable/skippable status | Every PR; fail CI on new unstable types |
| Layout Inspector (recomposition counts) | See which composables recompose and why | When debugging excess recomposition |
| Composition Tracing | Frame-level composition timing in Android Studio | When Layout Inspector is not enough |
| Macrobenchmark | Measure startup, frame timing, jank in release | Per-release regression gate |

---

## When to Use

Load this skill when any of the following applies:

- Structuring a new Compose screen (Screen/Content split, state holder choice)
- Wiring a ViewModel to UI (`collectAsStateWithLifecycle`, `stateIn`, UiState shape)
- Choosing MVVM vs MVI for a feature
- Designing `UiState` or `UiAction` types (stability, sealed hierarchies)
- Reviewing a screen for architecture anti-patterns (ViewModel in child, one-shot events, unstable state)
- Scoping ViewModels to navigation destinations
- Deciding where to hoist state and how low to read it

---

## Critical Patterns

### 1. `collectAsStateWithLifecycle` — always, never `collectAsState`

From `androidx.lifecycle:lifecycle-runtime-compose`. Stops collecting when the lifecycle reaches `STOPPED` (app backgrounded, screen off), saving CPU and battery. `collectAsState()` collects forever regardless of lifecycle state.

This is a **Strongly Recommended** pattern in official Android docs — not optional.

```kotlin
// CORRECT
val uiState by viewModel.uiState.collectAsStateWithLifecycle()

// WRONG — collects forever
val uiState by viewModel.uiState.collectAsState()
```

### 2. `stateIn` canonical pattern

```kotlin
val uiState: StateFlow<CoursesUiState> = someFlow
    .stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000), // 5 s timeout survives rotation
        initialValue = CoursesUiState(),
    )
```

The 5-second timeout keeps the pipeline alive through screen rotations without restarting. It stops when the UI is truly gone (not just rotated). NEVER use `SharingStarted.Eagerly` — the pipeline stays active even when no UI observes it, wasting CPU/battery.

### 3. No `AndroidViewModel` — use `ViewModel` with constructor injection

```kotlin
// CORRECT — framework-decoupled, testable
@HiltViewModel
class CoursesViewModel @Inject constructor(
    private val loadCourses: LoadCoursesUseCase,
) : ViewModel() { ... }

// WRONG — couples ViewModel to Android framework, makes testing harder
class CoursesViewModel(application: Application) : AndroidViewModel(application) { ... }
```

### 4. No ViewModel instances in child composables

Pass only the state and lambdas that the child needs. Child composables receiving a ViewModel cannot be previewed, tested independently, or reused. Screen-level composables and navigation destinations are the ONLY valid ViewModel access points.

```kotlin
// CORRECT
@Composable
fun CoursesScreen(viewModel: CoursesViewModel = hiltViewModel()) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    CoursesContent(state = uiState, onAction = viewModel::onAction)
}

@Composable
fun CoursesContent(state: CoursesUiState, onAction: (CoursesAction) -> Unit) { ... }

// WRONG — child receives ViewModel
@Composable
fun CourseCard(viewModel: CoursesViewModel) { ... } // cannot preview or test in isolation
```

### 5. Events as state — never one-shot

Model navigation triggers, snackbars, and dialogs as `Boolean` or `sealed class` state fields in `UiState`, not as `Channel` or `SharedFlow` events. One-shot events are consumed and lost if the UI resubscribes; state is always replayable.

```kotlin
// CORRECT — navigation modelled as state
data class CoursesUiState(
    val navigateToCourseId: String? = null, // null = no navigation pending
    ...
)

// WRONG — event lost if UI resubscribes before consuming
private val _navigationEvent = MutableSharedFlow<String>()
val navigationEvent: SharedFlow<String> = _navigationEvent
```

### 6. Stable UI models

All properties MUST be `val`. Use `ImmutableList<T>` from `kotlinx.collections.immutable` or an `@Immutable` wrapper for list fields. Types with `var` properties are always inferred unstable — composables receiving them can never be skipped.

```kotlin
// CORRECT — fully stable
@Immutable
data class CourseUi(
    val id: String,
    val title: String,
    val isBookmarked: Boolean,
)

@Immutable
data class CoursesUiState(
    val courses: ImmutableList<CourseUi> = persistentListOf(),
    val isLoading: Boolean = false,
)

// WRONG — var makes the whole class unstable
data class CoursesUiState(
    var isLoading: Boolean = false, // var = unstable
    val courses: List<CourseUi> = emptyList(), // mutable List = unstable
)
```

### 7. Hoist state high, read state low

Hoist to the lowest common ancestor that needs to share state. But READ state as low in the tree as possible — pass `() -> T` lambdas to children for frequently-changing values so the read happens in the child's scope, not the parent's.

```kotlin
// CORRECT — pass lambda; scroll position read only in child scope
@Composable
fun Parent() {
    val listState = rememberLazyListState()
    Child(firstVisibleIndex = { listState.firstVisibleItemIndex })
}

@Composable
fun Child(firstVisibleIndex: () -> Int) {
    val index = firstVisibleIndex() // read deferred to this scope
}

// WRONG — parent reads and passes the value → parent recomposes on every scroll event
@Composable
fun Parent() {
    val listState = rememberLazyListState()
    Child(firstVisibleIndex = listState.firstVisibleItemIndex) // read HERE = parent recomposes
}
```

### 8. `@Stable` for plain class state holders

For reusable UI component state holders (not ViewModels), use a plain class annotated `@Stable` with `MutableState` properties. Do NOT use ViewModel for per-component state holders — they live too long and carry DI overhead.

```kotlin
@Stable
class MapState {
    private val _location = mutableStateOf<Position?>(null)
    val latitude by derivedStateOf { _location.value?.latitude }
    val longitude by derivedStateOf { _location.value?.longitude }

    fun changeLocation(position: Position) {
        _location.value = position
    }
}

@Composable
fun rememberMapState(): MapState = remember { MapState() }
```

### 9. Screen/Content split

One `Screen` composable accesses state and handles navigation callbacks (connects to ViewModel); one `Content` composable renders pure UI given immutable state. The `Content` composable is stateless, previewable, and testable in isolation.

```kotlin
// SCREEN — connects to ViewModel, handles navigation
@Composable
fun CoursesScreen(
    viewModel: CoursesViewModel = hiltViewModel(),
    onOpenCourse: (String) -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    CoursesContent(
        state = uiState,
        onAction = viewModel::onAction,
        onCourseClick = onOpenCourse,
        modifier = Modifier.fillMaxSize(),
    )
}

// CONTENT — pure, previewable, testable
@Composable
fun CoursesContent(
    state: CoursesUiState,
    onAction: (CoursesAction) -> Unit,
    onCourseClick: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    // Only renders — no ViewModel access
}
```

### 10. `_uiState.update { it.copy(...) }` for atomic updates

Prevents intermediate inconsistent states under concurrent coroutines.

```kotlin
// CORRECT — atomic under concurrency
_uiState.update { it.copy(isLoading = false, courses = newCourses) }

// WRONG — race condition possible
_uiState.value = _uiState.value.copy(isLoading = false, courses = newCourses)
```

---

## Pitfalls

| Pitfall | Fix | Phase Cost |
|---------|-----|------------|
| `collectAsState()` | `collectAsStateWithLifecycle()` | Collects forever vs. stops on STOPPED lifecycle |
| `SharingStarted.Eagerly` in `stateIn` | `WhileSubscribed(5_000)` | Pipeline active with no UI → wasted CPU/battery |
| `List<T>` in UiState | `ImmutableList<T>` or `@Immutable` wrapper | Composable always non-skippable (unstable type) |
| `var` properties in UiState data class | All `val` — use `MutableState` for reactive fields | Entire class inferred unstable |
| ViewModel instance passed to child composable | Pass `state: UiState` + `onAction: (Action) -> Unit` | Non-previewable, non-testable child |
| `AndroidViewModel` | `ViewModel` + `@HiltViewModel` constructor injection | Framework coupling, test friction |
| Reading list state in parent body | Pass `() -> List<T>` lambda or read in child scope | Full Composition on every list change |
| One-shot event via `Channel`/`SharedFlow` | Model as state field in `UiState` | Event lost on resubscription |
| `_uiState.value = _uiState.value.copy(x = y)` under concurrency | `_uiState.update { it.copy(x = y) }` | Race condition → intermediate inconsistent state |

---

## Code Examples

### MVVM — canonical ViewModel

```kotlin
@HiltViewModel
class CoursesViewModel @Inject constructor(
    private val loadCourses: LoadCoursesUseCase,
) : ViewModel() {

    private val _uiState = MutableStateFlow(CoursesUiState())
    val uiState: StateFlow<CoursesUiState> = _uiState
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), CoursesUiState())

    fun onAction(action: CoursesAction) {
        when (action) {
            is CoursesAction.BookmarkClicked -> toggleBookmark(action.id)
            CoursesAction.RetryClicked -> loadCourses()
        }
    }

    private fun toggleBookmark(courseId: String) {
        _uiState.update { state ->
            state.copy(
                courses = state.courses.map { course ->
                    if (course.id == courseId) course.copy(isBookmarked = !course.isBookmarked)
                    else course
                }.toPersistentList()
            )
        }
    }
}
```

### MVI — reducer pattern

```kotlin
@Immutable
data class CoursesState(
    val isLoading: Boolean = false,
    val courses: ImmutableList<CourseUi> = persistentListOf(),
    val error: String? = null,
)

sealed interface CoursesIntent {
    data object Load : CoursesIntent
    data class BookmarkClicked(val id: String) : CoursesIntent
}

sealed interface CoursesChange {
    data object Loading : CoursesChange
    data class Data(val courses: List<CourseUi>) : CoursesChange
    data class Failure(val message: String) : CoursesChange
}

private fun CoursesState.reduce(change: CoursesChange): CoursesState = when (change) {
    CoursesChange.Loading -> copy(isLoading = true, error = null)
    is CoursesChange.Data -> copy(isLoading = false, courses = change.courses.toPersistentList(), error = null)
    is CoursesChange.Failure -> copy(isLoading = false, error = change.message)
}
```

### UiAction with nested hierarchy

```kotlin
// Sealed hierarchy allows passing subtype lambda to child — no extra wrappers needed
sealed class CoursesAction {
    sealed class Header : CoursesAction() {
        data object Refresh : Header()
    }
    sealed class Item : CoursesAction() {
        data class BookmarkClicked(val id: String) : Item()
        data class CourseClicked(val id: String) : Item()
    }
}

// CourseCard receives (CoursesAction.Item) -> Unit — a subtype of (CoursesAction) -> Unit
@Composable
fun CourseCard(
    model: CourseUi,
    onAction: (CoursesAction.Item) -> Unit,
    modifier: Modifier = Modifier,
) { ... }
```

### UiState with nested sub-state

```kotlin
// Each composable section receives only its slice — no over-passing
@Immutable
data class UserProfileUiState(
    val header: Header,
    val details: Details,
) {
    @Immutable
    data class Header(val fullName: String, val avatarUrl: String?)

    @Immutable
    data class Details(val followersCount: Int, val bio: String)
}
```

---

## Commands

No CLI commands are specific to this skill. Relevant Gradle dependencies:

```kotlin
// Lifecycle-aware state collection
implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.+")

// Stable collections for UiState
implementation("org.jetbrains.kotlinx:kotlinx-collections-immutable:0.3.7")

// Hilt ViewModel injection
implementation("com.google.dagger:hilt-android:2.51.+")
kapt("com.google.dagger:hilt-compiler:2.51.+")
implementation("androidx.hilt:hilt-navigation-compose:1.2.+")
```

---

## Related Skills

| Skill | Path | What It Adds |
|-------|------|--------------|
| `compose-composition-core` | `../compose-composition-core/SKILL.md` | Stability, recomposition, and state fundamentals that UiState design depends on |
| `compose-effects` | `../compose-effects/SKILL.md` | `LaunchedEffect` patterns used in Screen composables for one-time events |
| `compose-navigation-nav3` | `../compose-navigation-nav3/SKILL.md` | How ViewModel scoping works per-destination in Nav3 |

---

## Resources

| File | Covers |
|------|--------|
| [references/README.md](references/README.md) | Index of all reference files |
| [references/clean-architecture-layers.md](references/clean-architecture-layers.md) | CA layers, UDF, Screen/Content split |
| [references/mvvm-patterns.md](references/mvvm-patterns.md) | ViewModel, UiState, collectAsStateWithLifecycle |
| [references/conventions.md](references/conventions.md) | Naming, Component/Factory/Effect types |

---

## Validation

- **Validated**: 2026-05
- **Target**: Kotlin 2.0.20+, Compose BOM 2026.05.xx, lifecycle-runtime-compose 2.8+
- **Stable APIs**: `collectAsStateWithLifecycle`, `stateIn`, `WhileSubscribed`, `@HiltViewModel`, `@Stable`, `@Immutable`, `ImmutableList` (kotlinx.collections.immutable)
- **Not Recommended**: `AndroidViewModel` (official docs 2026-05), `collectAsState()` (use lifecycle-aware variant), `SharingStarted.Eagerly`
- **Review cadence**: Quarterly
