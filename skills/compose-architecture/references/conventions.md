# Conventions and Modern Practices

## Compose Naming (differs from Kotlin style guide)

- Constants and enum values: **CamelCase** (`DefaultKeyName`, `Status.Idle`)
- NOT `SCREAMING_SNAKE_CASE`

## Three `@Composable` Function Types

| Type | Returns | Naming | Purpose |
|------|---------|--------|---------|
| **Component** | `Unit` only | PascalCase | Emits UI; `modifier` first optional param |
| **Factory** | Non-Unit (e.g., `State`) | `rememberXxx` | Creates remembered state |
| **Effect** | `Unit` | PascalCase | Side effect with no UI emission |

Components MUST NOT return values. Factories MUST be `@Composable`.

## Component Conventions

```kotlin
@Composable
fun Badge(text: String, modifier: Modifier = Modifier, icon: (@Composable () -> Unit)? = null)
```

- `modifier` at first optional position
- Applied at outermost UI root
- Single UI root where possible

## Stable Types in UI Layer

| Prefer | Avoid |
|--------|-------|
| `@Immutable data class XxxUi(...)` | Mutable classes in parameters |
| `ImmutableList<T>` | `List<T>` in UiState |
| Lambda callbacks | Passing ViewModel/repository |
| `@Stable` on state holders | Raw interfaces without `@Stable` |

## Screen Naming

- `FeatureScreen` — bridging composable
- `FeatureScreenContent` — stateless UI
- `FeatureViewModel` — presentation logic

## Preview Strategy

Content composables are preview-friendly — pass sample `UiState` directly without ViewModel.

## MVI Alternative

Same boundaries apply: Intent/Action up, State down. ViewModel reduces intents to state updates. Compose integration identical to MVVM collection patterns.

## Parameter Ordering

Required params → `modifier: Modifier = Modifier` → optional params → trailing lambda slots for content/callbacks.
