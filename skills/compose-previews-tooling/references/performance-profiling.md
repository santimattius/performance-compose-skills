# Performance Profiling

## Profile-in-Release Mandate

Debug builds disable:
- R8 optimization
- Strong Skipping Mode (lambdas treated unstable)
- Compose compiler optimizations

**NEVER profile performance in debug builds.** Use `benchmark` or `release` build type.

```kotlin
buildTypes {
    create("benchmark") {
        initWith(getByName("release"))
        signingConfig = signingConfigs.getByName("debug")
        matchingFallbacks += listOf("release")
        isDebuggable = false
    }
}
```

## Compose Compiler Reports

```kotlin
composeCompiler {
    reportsDestination = layout.buildDirectory.dir("compose_compiler")
    metricsDestination = layout.buildDirectory.dir("compose_compiler")
}
```

Run on release/benchmark only. Interpret:
- `restartable skippable` — can skip when stable inputs unchanged ✅
- `unstable` parameter — always recomposes — investigate ⚠️

```bash
./gradlew assembleRelease
grep "unstable" build/compose_compiler/*-classes.txt
```

## Baseline Profiles

Ship `baseline-prof.txt` in release to pre-compile hot paths (startup, scroll). Generate with Macrobenchmark + Baseline Profile generator.

Profile generation also requires non-debuggable build matching release optimizations.

## Composition Tracing

Add `runtime-tracing` artifact. Keep ProGuard rules so trace markers survive R8:

```proguard
-keep class androidx.compose.runtime.CompositionTracing { *; }
-keepclassmembers class ** {
    @androidx.compose.runtime.Composable <methods>;
}
```

View in Android Studio CPU Profiler alongside system traces.

## Macrobenchmark

Measure startup, frame timing, energy on physical devices. Use `benchmark` build type. Compare with/without Baseline Profile.

## Screenshot Testing — ALPHA Warning

> **ALPHA — androidx.compose.ui.test.screenshot 0.0.1-alpha14**: API may break. Requires AGP 8.5+ (9.0+ for IDE integration).

**Stable CI alternatives:**

| Library | Runtime | Best for |
|---------|---------|----------|
| Paparazzi | JVM (LayoutLib) | Fast CI, no emulator |
| Roborazzi | Robolectric | Strong diffs, Robolectric projects |
| Shot | Instrumentation | Real Android runtime |
| Dropshots | Instrumentation | In-test comparison |

Decision tree:
```
Need real Android runtime?
├── YES → Shot or Dropshots
└── NO → Use Robolectric? → Roborazzi : Paparazzi
```

## 3-Phase Performance Model (Apply to Profiling)

When investigating jank, identify which phase is hot:
1. **Composition** — recomposition counts (Layout Inspector, Composition Tracing)
2. **Layout** — measure/layout passes (Systrace)
3. **Drawing** — overdraw, layer count (GPU rendering profile)

Fix at the correct phase — animating in Composition when Drawing suffices wastes work.
