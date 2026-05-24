# Discovery Playbook

Run at the start of every audit (Phase 1). Persist outputs in the report header.

## 1. Detect project type

| Signal | Classification |
|--------|----------------|
| `src/commonMain/` + `src/androidMain/` or `src/iosMain/` | `cmp` |
| Multiple KMP targets without shared Compose UI | `kmp` (may skip UI audit) |
| `src/main/` only, Android app module | `android` |

```bash
# Source sets
find . -type d -name 'commonMain' -o -name 'androidMain' -o -name 'iosMain' 2>/dev/null | head -20
```

## 2. Compose version

Search Gradle files and version catalogs:

```bash
rg -n 'compose-bom|org\.jetbrains\.compose|compose\.runtime' --glob '*.{gradle.kts,gradle,toml}' .
```

Record BOM version or plugin version string.

## 3. Compiler reports

```bash
rg -n 'reportsDestination|metricsDestination|compose\.compiler\.plugins\.kotlin:reportsDestination' .
```

If present, note output directory for cross-validation of `COR-UNSTABLE-PARAM`. If absent, plan `PRV-NO-COMPILER-REPORTS` suggestion after discovery.

## 4. Entry points

```bash
rg -n '@Composable\s+fun\s+\w*App\b|class MainActivity' -t kotlin --glob '!**/build/**'
```

Prioritize these files when `sampling: top-level+entry-drill`.

## 5. Sampling strategy

| `.kt` file count (excluding build/) | Strategy |
|-------------------------------------|----------|
| ≤ 300 | `full` — run all pattern_ids |
| > 300 | `top-level+entry-drill` — all patterns on entry points + screens; sample other modules |

## 6. STOP condition

If no Compose dependency is found in Gradle/catalog files and no `@Composable` in source:

```
No Compose codebase detected — audit stopped.
```

Do not emit findings against skill markdown or docs-only trees.

## 7. Interop surfaces (hybrid apps)

When `AndroidView`, `ComposeView`, or Fragment+Compose coexistence is detected, record counts in report header as `interop_surfaces`:

```bash
rg -c 'AndroidView\s*\(' -t kotlin --glob '!**/build/**' || true
rg -c 'ComposeView|AbstractComposeView' -t kotlin --glob '!**/build/**' || true
rg -c 'DialogFragment|BottomSheetDialogFragment' -t kotlin --glob '!**/build/**' || true
rg -l 'setViewCompositionStrategy' -t kotlin --glob '!**/build/**' | wc -l
```

Example header field:

```text
interop_surfaces: { android_view: 12, compose_view: 8, dialog_fragment: 3, composition_strategy_files: 5 }
```

## 8. Discovery output checklist

- [ ] `project_type`
- [ ] `compose_version`
- [ ] `compiler_reports_available`
- [ ] `source_sets[]`
- [ ] `entry_points[]`
- [ ] `sampling`
- [ ] `interop_surfaces` (if hybrid)
