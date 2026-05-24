---
name: compose-audit
description: >
  Context-aware audit of Jetpack Compose and Compose Multiplatform codebases.
  Discovers project shape, classifies findings by severity (critical/warning/suggestion),
  and routes each finding to the canonical performance skill for the fix.
  Trigger: "audit my Compose project", "review CMP code", "find perf issues in Compose",
  "compose code review", "recomposition audit", "CMP audit".
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

Audits prioritize issues that force **Composition** restarts or break lifecycle/correctness. Layout and Drawing phase issues are classified as **warning** unless they cause measurable jank with evidence.

## Performance Toolchain

> WARNING: NEVER profile in debug builds. Debug disables R8, inlining, and Strong Skipping — numbers are meaningless. Always profile a release build with `profileable` enabled or a benchmark build type.

| Tool | Use For | When |
|------|---------|------|
| Compose Compiler Reports | Unstable params, skippable/restartable flags | Cross-validate `COR-UNSTABLE-PARAM` |
| Layout Inspector | Recomposition counts | After audit flags hot composables |
| Composition Tracing | Frame-level composition timing | When warnings cluster on one screen |
| Macrobenchmark | Release regression (Android) | Consumer apps only — not this skills repo |
| `android docs search` | Validate Jetpack Compose API claims | Before finalizing Android findings |
| context7 MCP | Validate CMP claims | Before finalizing `CMP-*` findings |

---

## When to Use

Use this skill when:

- Auditing an existing Compose or Compose Multiplatform codebase for performance and correctness
- The user asks for a "Compose review", "recomposition audit", or "CMP audit"
- You need a severity-ranked report that points to the right fix skill
- Onboarding to an unfamiliar Compose project and need a structured first pass

## When NOT to Use

Do **not** load this skill when the user already named a narrow topic — load the specific skill instead:

| User intent | Load instead |
|-------------|--------------|
| Fix `LaunchedEffect` keys | `compose-effects` |
| Unstable params / skipping | `compose-composition-core` |
| Custom modifiers / draw phase | `compose-modifier-system` |
| Nav3 migration | `compose-navigation-nav3` |
| View↔Compose interop (AndroidView, ComposeView, hybrid screen) | `compose-views-interop` |
| Accessibility only | `compose-quality` |

This skill **diagnoses and routes**. It does not replace downstream remediation guidance.

---

## Audit Workflow

Execute phases in order. Do not skip discovery.

```
Phase 1 Discovery → Phase 2 Static Scan → Phase 3 Severity → Phase 4 Routing → Phase 5 Report
```

### Phase 1 — Discovery

See [references/discovery-playbook.md](references/discovery-playbook.md).

Outputs for the report header: `project_type`, `compose_version`, `compiler_reports_available`, `source_sets`, `entry_points`, `sampling`.

**STOP:** If no Compose dependency and no `@Composable` in project sources → emit `No Compose codebase detected` and exit.

### Phase 2 — Static Scan

Load [references/detection-catalog.md](references/detection-catalog.md) and [assets/routing-table.md](assets/routing-table.md).

For each `pattern_id`, run the ripgrep recipe (or `Grep` tool with the same pattern). Record:

```text
raw_signal:
  pattern_id: EFF-LAUNCHED-EFFECT-UNIT
  file: ...
  line: ...
  snippet: ...
  source_set: androidMain | main | commonMain | ...
```

**Rule:** Read 5–15 lines of context. If the match is a false positive, discard — do not list in the report.

### Phase 3 — Severity Classification

Apply [references/severity-rubric.md](references/severity-rubric.md). Start from **Default Severity** in the routing table. You may **upgrade** with evidence; never downgrade.

### Phase 4 — Routing

Look up `pattern_id` in [assets/routing-table.md](assets/routing-table.md). Apply **Disambiguator** when present:

| pattern_id | Rule |
|------------|------|
| ARCH-STATE-FLOW-NO-LIFECYCLE | Screen composable owns ViewModel → `compose-architecture` |
| EFF-COLLECT-NOT-LIFECYCLE | Otherwise generic `collectAsState()` → `compose-effects` |

If no row matches, add to **Notes** only — never as a Finding.

### Phase 5 — Report Generation

Copy [assets/AUDIT-REPORT.md](assets/AUDIT-REPORT.md), fill placeholders, enforce caps:

| Severity | Max findings |
|----------|--------------|
| critical | 10 |
| warning | 20 |
| suggestion | 30 |

Default: render inline in chat. On request, write `audit/AUDIT-REPORT-<timestamp>.md` at project root.

Order **Next Skills to Load** by severity weight (critical=3, warning=2, suggestion=1) per skill.

---

## Detection Catalog (summary)

Full heuristics: [references/detection-catalog.md](references/detection-catalog.md). Routing: [assets/routing-table.md](assets/routing-table.md).

| Area | pattern_id examples | Routes to |
|------|---------------------|-----------|
| Composition | COR-COMPOSITION-WRITE, COR-UNSTABLE-PARAM, COR-LAZY-NO-KEY | compose-composition-core |
| Modifiers | MOD-ORDER, MOD-DRAW-IN-COMPOSITION | compose-modifier-system |
| Effects | EFF-LAUNCHED-EFFECT-UNIT, EFF-GLOBAL-SCOPE, EFF-RUNBLOCKING-IN-COMPOSE | compose-effects |
| Animations | ANI-STATE-IN-COMPOSITION, ANI-INFINITE-TRANSITION-LEAK | compose-animations |
| Architecture | ARCH-SCREEN-CONTENT-MIXED, ARCH-MUTATING-UI-STATE-IN-COMPOSITION | compose-architecture |
| Navigation | NAV-NAV2-LEFTOVER, NAV-NAV3-NO-DECORATOR | compose-navigation-nav3 |
| Tooling | PRV-NO-COMPILER-REPORTS, PRV-NO-BASELINE-PROFILE | compose-previews-tooling |
| Quality | QLT-NO-SEMANTICS, QLT-LIVE-REGION-MISSING | compose-quality |
| Interop | INTEROP-COMPOSEVIEW-WRONG-STRATEGY, INTEROP-RECYCLERVIEW-RESET-CONTENT, INTEROP-ANDROIDVIEW-UPDATE-HEAVY | compose-views-interop |
| CMP | CMP-PLATFORM-API-IN-COMMON, CMP-REMEMBER-PLATFORM-LEAK | compose-architecture / compose-composition-core |

---

## Severity Rubric

| Tier | When to use |
|------|-------------|
| **critical** | Crash, leak, ANR, lifecycle break, correctness |
| **warning** | Performance or stability regression with evidence |
| **suggestion** | Idiomatic improvement; low-confidence CMP heuristics |

Details: [references/severity-rubric.md](references/severity-rubric.md).

---

## Skill Routing

**Invariants:**

1. Every finding has exactly one `pattern_id` and one canonical skill.
2. Fix sketches are 1–3 lines — point to a section in the downstream `SKILL.md`, do not paste full fixes.
3. Unrouteable signals → **Notes**, not Findings.

**Canonical skills** (from [AGENTS.md](../../AGENTS.md)):

- `compose-composition-core`
- `compose-modifier-system`
- `compose-effects`
- `compose-animations`
- `compose-architecture`
- `compose-navigation-nav3`
- `compose-previews-tooling`
- `compose-quality`

---

## Compose vs Compose Multiplatform

| Concern | Android Compose | Compose Multiplatform |
|---------|-------------------|------------------------|
| Source sets | `src/main/` | `commonMain`, `androidMain`, `iosMain`, … |
| Lifecycle state | `collectAsStateWithLifecycle` in `main`/`androidMain` | Requires CMP 1.6+ artifact in `commonMain` |
| Platform APIs | OK in `main` | Forbidden in `commonMain` — use `expect/actual` |
| CMP severity | Default from table | CMP-only heuristics often **suggestion**; `CMP-PLATFORM-API-IN-COMMON` stays **critical** |

Detail: [references/cmp-considerations.md](references/cmp-considerations.md). Official CMP docs: https://kotlinlang.org/docs/multiplatform/compose-multiplatform.html

---

## Tooling Integration

### ripgrep / Grep

Prefer `rg` (respects `.gitignore`). Scope with `--glob '**/src/commonMain/**'` for CMP patterns.

```bash
rg -n 'LaunchedEffect\s*\(\s*Unit\s*\)' -t kotlin
```

### Compose Compiler Reports

If `reportsDestination` exists, read `*-classes.txt` and `*-composables.txt` for unstable/skippable validation.

### android-cli — docs search

For Jetpack Compose API recommendations:

```bash
android docs search 'collectAsStateWithLifecycle'
```

Store top result URL in `evidence_docs`. If CLI unavailable: `evidence_docs: (android-cli unavailable)`.

### context7 MCP (CMP)

For `CMP-*` findings, resolve docs via context7 (`/jetbrains/compose-multiplatform`, `/kotlinlang/docs`).

---

## Report Contract

Every audit MUST include:

- Discovery metadata (project type, version, sampling)
- Summary counts per severity (with cap flags)
- Findings with: `pattern_id`, file:line, evidence snippet, rationale, recommended skill link, fix sketch, docs consulted
- Overflow table when caps exceeded
- **Next Skills to Load** ordered list

Template: [assets/AUDIT-REPORT.md](assets/AUDIT-REPORT.md).

---

## Pitfalls (when running the audit)

| Pitfall | Mitigation |
|---------|------------|
| Reporting regex hits without reading code | Mandatory context read before Finding |
| Duplicating fix guidance from other skills | Fix sketch only; load downstream skill for implementation |
| Auditing this skills repo as an app | Discovery STOP — no Gradle Compose app |
| Report bloat | Enforce 10/20/30 caps; aggregate overflow by `pattern_id` |
| Wrong route for collectAsState | Apply ARCH vs EFF disambiguator |

---

## Deviations from other skills in this repo

- **`assets/` folder** — templates (`AUDIT-REPORT.md`, `routing-table.md`) are agent-fillable; `references/` is read-only background.
- **No Kotlin remediation samples in this file** — remediation lives in the nine routed skills.
- **Pairs with all nine skills** — there is no single "vs" neighbor section; use Skill Routing + routing table.

---

## References

| File | Purpose |
|------|---------|
| [references/README.md](references/README.md) | Index + downstream skill links |
| [references/discovery-playbook.md](references/discovery-playbook.md) | Phase 1 |
| [references/detection-catalog.md](references/detection-catalog.md) | Phase 2 patterns |
| [references/severity-rubric.md](references/severity-rubric.md) | Phase 3 |
| [references/cmp-considerations.md](references/cmp-considerations.md) | CMP rules |
| [assets/routing-table.md](assets/routing-table.md) | Phase 4 source of truth |
| [assets/AUDIT-REPORT.md](assets/AUDIT-REPORT.md) | Phase 5 template |
