# References — compose-audit

Self-contained reference material for audits. Templates live in [../assets/](../assets/) (agent-fillable outputs); this folder is read-only background.

| File | Covers |
|------|--------|
| [discovery-playbook.md](discovery-playbook.md) | Android vs KMP vs CMP detection, versions, compiler reports, sampling |
| [detection-catalog.md](detection-catalog.md) | Full pattern_id heuristics (ripgrep recipes) |
| [severity-rubric.md](severity-rubric.md) | critical / warning / suggestion rules and upgrades |
| [cmp-considerations.md](cmp-considerations.md) | Source sets, expect/actual, platform API leaks |

## Downstream skills (remediation)

Route findings to exactly one of these — do not duplicate their guidance in audit output:

| Skill | Link |
|-------|------|
| compose-composition-core | [SKILL.md](../../compose-composition-core/SKILL.md) |
| compose-modifier-system | [SKILL.md](../../compose-modifier-system/SKILL.md) |
| compose-effects | [SKILL.md](../../compose-effects/SKILL.md) |
| compose-animations | [SKILL.md](../../compose-animations/SKILL.md) |
| compose-architecture | [SKILL.md](../../compose-architecture/SKILL.md) |
| compose-navigation-nav3 | [SKILL.md](../../compose-navigation-nav3/SKILL.md) |
| compose-previews-tooling | [SKILL.md](../../compose-previews-tooling/SKILL.md) |
| compose-quality | [SKILL.md](../../compose-quality/SKILL.md) |
