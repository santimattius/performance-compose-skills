# Compose Audit Report

- **Project**: {{project_name_or_path}}
- **Type**: {{project_type}} <!-- android | kmp | cmp -->
- **Compose version**: {{compose_version}}
- **Source sets**: {{source_sets_csv}}
- **Compiler Reports**: {{compiler_reports_available}}
- **Sampling**: {{sampling_strategy}}
- **Scanned at**: {{iso_timestamp}}

## Summary

| Severity | Count | Capped? |
|---|---|---|
| critical | {{n_critical}} | {{capped_critical}} |
| warning | {{n_warning}} | {{capped_warning}} |
| suggestion | {{n_suggestion}} | {{capped_suggestion}} |

## Critical Findings

<!-- Cap: 10. Repeat block per finding. -->

### C-{{ordinal}} — {{symptom}}

- **pattern_id**: {{pattern_id}}
- **File**: `{{file}}:{{line}}`
- **Source set**: {{source_set}}
- **Evidence**:

```kotlin
{{snippet_with_3_lines_context}}
```

- **Rationale**: {{one_or_two_sentences_why_this_breaks}}
- **Recommended skill**: [`{{canonical_skill}}`](../../skills/{{canonical_skill}}/SKILL.md)
- **Fix sketch** (1–3 lines; point to downstream skill section, do not paste full fix):

> {{minimal_sketch_pointing_to_downstream_skill_section}}

- **Docs consulted**: {{evidence_docs}}

## Warnings

<!-- Cap: 20. Same shape as Critical; use W-{{ordinal}} headings. -->

### W-{{ordinal}} — {{symptom}}

- **pattern_id**: {{pattern_id}}
- **File**: `{{file}}:{{line}}`
- **Source set**: {{source_set}}
- **Evidence**:

```kotlin
{{snippet_with_3_lines_context}}
```

- **Rationale**: {{one_or_two_sentences_why_this_breaks}}
- **Recommended skill**: [`{{canonical_skill}}`](../../skills/{{canonical_skill}}/SKILL.md)
- **Fix sketch**:

> {{minimal_sketch_pointing_to_downstream_skill_section}}

- **Docs consulted**: {{evidence_docs}}

## Suggestions

<!-- Cap: 30. Same shape; use S-{{ordinal}} headings. -->

### S-{{ordinal}} — {{symptom}}

- **pattern_id**: {{pattern_id}}
- **File**: `{{file}}:{{line}}`
- **Source set**: {{source_set}}
- **Evidence**:

```kotlin
{{snippet_with_3_lines_context}}
```

- **Rationale**: {{one_or_two_sentences_why_this_breaks}}
- **Recommended skill**: [`{{canonical_skill}}`](../../skills/{{canonical_skill}}/SKILL.md)
- **Fix sketch**:

> {{minimal_sketch_pointing_to_downstream_skill_section}}

- **Docs consulted**: {{evidence_docs}}

## Overflow Summary (capped)

| pattern_id | Severity | Extra instances | Top 3 files |
|---|---|---|---|
| {{pattern_id}} | {{severity}} | {{extra_count}} | {{top3_files}} |

## Notes (unrouteable, informational only)

<!-- Raw signals without a routing-table row. Never listed as Findings. -->

- {{note_1}}

## Next Skills to Load

Load these skills before applying fixes (ordered by severity weight: critical=3, warning=2, suggestion=1):

1. {{skill_1}} — {{counts_by_severity_for_skill_1}}
2. {{skill_2}} — {{counts_by_severity_for_skill_2}}
3. {{skill_3}} — {{counts_by_severity_for_skill_3}}
