# Compose Multiplatform Considerations

Official reference: [Compose Multiplatform](https://kotlinlang.org/docs/multiplatform/compose-multiplatform.html)

Validate CMP-specific findings with **context7** MCP (`/jetbrains/compose-multiplatform`, `/kotlinlang/docs`) and record URLs in `evidence_docs`.

## Source sets

| Set | Audit focus |
|-----|-------------|
| `commonMain` | Shared UI — no platform imports; no Android types in `remember` |
| `androidMain` | Android lifecycle, `collectAsStateWithLifecycle`, Nav3 decorators |
| `iosMain` / `desktopMain` / `jsMain` / `wasmJsMain` | Platform APIs OK here; cross-check `expect`/`actual` |

## Severity policy for CMP

| Rule | Detail |
|------|--------|
| Default | CMP-only heuristic findings start at **suggestion** unless pattern_id says otherwise |
| Forced critical | `CMP-PLATFORM-API-IN-COMMON` stays **critical** |
| Lifecycle | `collectAsStateWithLifecycle` in `commonMain` requires CMP 1.6+ + lifecycle artifact — do not flag older projects without checking BOM |

## Platform API in commonMain

Forbidden imports (non-exhaustive):

- `android.*`
- `platform.UIKit.*`
- `java.awt.*`
- `androidx.navigation` in shared UI without CMP Nav3 setup

```bash
rg -n '^import (android\.|platform\.UIKit|java\.awt\.)' --glob '**/src/commonMain/**' -t kotlin
```

Route: `CMP-PLATFORM-API-IN-COMMON` → `compose-architecture` (boundary) + note CMP docs for `expect/actual` split.

## expect / actual

```bash
rg -n '^expect (fun|class|object)' --glob '**/src/commonMain/**' -t kotlin
```

For each `expect`, verify `actual` exists in at least one target source set. Missing actual → `CMP-EXPECT-NO-ACTUAL` (**warning**).

## remember platform leaks

```bash
rg -n 'remember\s*\{' --glob '**/src/commonMain/**' -t kotlin -A 2
```

Flag captures of `Context`, `Activity`, `UIViewController`, etc. → `CMP-REMEMBER-PLATFORM-LEAK` → `compose-composition-core`.

## Navigation on CMP

- Nav2 in CMP shared code → `NAV-NAV2-LEFTOVER` → `compose-navigation-nav3`
- Nav3 without lifecycle decorator on Android → `NAV-NAV3-NO-DECORATOR`

## Tooling limits (out of audit scope)

- Macrobenchmark: Android only
- Layout Inspector: Android only
- iOS Instruments / Desktop JFR: not required for this skill
