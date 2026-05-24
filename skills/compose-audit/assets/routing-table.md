# Routing Table — compose-audit

> Source of truth: every finding `pattern_id` maps to exactly one skill.
> Keep in sync with [references/detection-catalog.md](../references/detection-catalog.md).

| pattern_id | Symptom | Default Severity | Source Set Scope | Canonical Skill | Disambiguator (if any) |
|---|---|---|---|---|---|
| COR-COMPOSITION-WRITE | Write to MutableState in composable body (backwards-write) | critical | any | compose-composition-core | — |
| COR-UNSTABLE-PARAM | Unstable @Composable parameter type | warning | any | compose-composition-core | — |
| COR-LAZY-NO-KEY | Lazy items() without key lambda | warning | any | compose-composition-core | — |
| COR-DERIVED-EQUAL | derivedStateOf where output equals input | suggestion | any | compose-composition-core | — |
| COR-STATIC-LOCAL-VARYING | staticCompositionLocalOf for runtime-varying value | warning | any | compose-composition-core | — |
| MOD-ORDER | Modifier chain order anti-pattern | warning | any | compose-modifier-system | — |
| MOD-DRAW-IN-COMPOSITION | Heavy draw work outside draw/graphicsLayer lambda | warning | any | compose-modifier-system | — |
| MOD-NEW-MODIFIER-PER-RECOMP | Modifier rebuilt per item without hoist | suggestion | any | compose-modifier-system | — |
| EFF-LAUNCHED-EFFECT-UNIT | LaunchedEffect(Unit) with varying body deps | critical | any | compose-effects | — |
| EFF-GLOBAL-SCOPE | GlobalScope or orphan Job in composable/effect | critical | any | compose-effects | — |
| EFF-DISPOSABLE-EMPTY-DISPOSE | DisposableEffect with empty onDispose | warning | any | compose-effects | — |
| EFF-COLLECT-NOT-LIFECYCLE | collectAsState() on Android where lifecycle-aware exists | warning | androidMain, main | compose-effects | Screen owns ViewModel → use ARCH-STATE-FLOW-NO-LIFECYCLE instead |
| EFF-RUNBLOCKING-IN-COMPOSE | runBlocking inside @Composable or LaunchedEffect | critical | any | compose-effects | — |
| ANI-STATE-IN-COMPOSITION | Animatable.value read in composition body | warning | any | compose-animations | — |
| ANI-ANIMATE-CONTENT-SIZE-MISUSE | animateContentSize on high-churn container | suggestion | any | compose-animations | — |
| ANI-INFINITE-TRANSITION-LEAK | rememberInfiniteTransition without lifecycle gating | warning | any | compose-animations | — |
| ARCH-STATE-FLOW-NO-LIFECYCLE | collectAsState in Screen that owns ViewModel | warning | androidMain, main | compose-architecture | Not a Screen/VM owner → route EFF-COLLECT-NOT-LIFECYCLE |
| ARCH-SCREEN-CONTENT-MIXED | Single composable injects VM and renders UI | warning | any | compose-architecture | — |
| ARCH-MUTATING-UI-STATE-IN-COMPOSITION | UiState mutated from composition body | critical | any | compose-architecture | — |
| NAV-NAV2-LEFTOVER | Nav2 compose APIs while Nav3 is available | warning | any | compose-navigation-nav3 | — |
| NAV-NAV3-NO-DECORATOR | NavDisplay without ViewModel lifecycle decorator | warning | any | compose-navigation-nav3 | — |
| NAV-NAVKEY-NOT-PARCELABLE | NavKey without @Parcelize on Android | warning | androidMain, main | compose-navigation-nav3 | — |
| PRV-NO-PREVIEW-PARAM | Public UI composable without @Preview | suggestion | any | compose-previews-tooling | — |
| PRV-NO-COMPILER-REPORTS | composeCompiler reportsDestination missing | suggestion | any | compose-previews-tooling | — |
| PRV-NO-BASELINE-PROFILE | Release app without baselineprofiles module | suggestion | any | compose-previews-tooling | — |
| QLT-NO-SEMANTICS | Clickable without semantics/contentDescription | warning | any | compose-quality | — |
| QLT-MERGE-DESCENDANTS-MISSING | Custom control without mergeDescendants | suggestion | any | compose-quality | — |
| QLT-LIVE-REGION-MISSING | Dynamic status text without liveRegion | suggestion | any | compose-quality | — |
| CMP-PLATFORM-API-IN-COMMON | Platform import in commonMain | critical | commonMain | compose-architecture | — |
| CMP-EXPECT-NO-ACTUAL | expect declaration without matching actual | warning | commonMain | compose-architecture | — |
| CMP-REMEMBER-PLATFORM-LEAK | remember { platform type } in commonMain | warning | commonMain | compose-composition-core | — |

## Invariants

1. Every `pattern_id` is unique.
2. Every `Canonical Skill` is one of the eight skills in [AGENTS.md](../../../AGENTS.md).
3. No row lists more than one canonical skill.
4. Unmatched signals go to **Notes** in the audit report, never **Findings**.
