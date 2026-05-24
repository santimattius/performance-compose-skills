# Severity Rubric

Apply after static scan (Phase 3). Default severity comes from [assets/routing-table.md](../assets/routing-table.md).

## Tiers

| Tier | Definition | Examples |
|------|------------|----------|
| **critical** | Crash, leak, ANR, lifecycle break, proven correctness break | `GlobalScope` in composable; `runBlocking` in UI; backwards-write to state in composition; platform API in `commonMain` |
| **warning** | Likely performance or stability regression with code evidence | Unstable list param on hot composable; `LaunchedEffect(Unit)` with captured changing id; missing `collectAsStateWithLifecycle` on Android |
| **suggestion** | Idiomatic improvement or low-confidence CMP guidance | Missing `@Preview`; missing compiler reports flag; possible `expect/actual` split |

## Upgrade rules (allowed)

- `EFF-GLOBAL-SCOPE` inside `LazyColumn` item or scroll handler → upgrade to **critical**
- `COR-UNSTABLE-PARAM` on root screen composable with compiler report "unstable" → keep **warning** (do not downgrade to suggestion)
- `CMP-*` findings: default stays unless rubric forces **critical** (e.g. `CMP-PLATFORM-API-IN-COMMON`)

## Downgrade rules (forbidden)

Never downgrade below the routing table default. Discard the signal instead if evidence is weak.

## Evidence-only policy

| Situation | Action |
|-----------|--------|
| Regex match but code is safe in context | Discard; optional one-line in agent reasoning only |
| Regex match + ambiguous context | Discard or emit **suggestion** only if human review would help |
| Regex match + clear violation | Emit finding at default or upgraded severity |

## Suppression (reporting)

Do not report:

- Generated code (`build/`, `generated/`)
- Test-only violations unless user asked to audit tests
- Third-party dependencies under `build/` or vendored AAR sources

## Per-severity caps (Phase 5)

| Tier | Max findings in report |
|------|------------------------|
| critical | 10 |
| warning | 20 |
| suggestion | 30 |

Aggregate duplicate `pattern_id` rows in **Overflow Summary**.
