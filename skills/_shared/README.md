# _shared/ — Shared References

This directory contains reference files used by multiple skills. Every `SKILL.md` in this repo links here via its `## CMP Applicability` section.

## Contents

| File | Description |
|------|-------------|
| [`cmp-platform.md`](cmp-platform.md) | Canonical CMP platform rules: source-set map, forbidden imports, expect/actual patterns, lifecycle version gates, DI, navigation, view interop, tooling matrix, per-skill applicability index, and version pinning. |

## Installation note

The `_shared/` directory is **not a skill** and is not automatically installed by `npx skills add --skill '*'`. See [`../../docs/INSTALL.md`](../../docs/INSTALL.md) for the manual copy step required to make cross-skill links resolve after a per-skill install.

## Usage

Each `SKILL.md` references `_shared/cmp-platform.md` via a relative link:

```markdown
> Canonical CMP rules: [`../_shared/cmp-platform.md`](../_shared/cmp-platform.md)
```

When installed, agents follow this link to load the full CMP platform reference in a second hop — keeping each skill self-contained while avoiding duplication.
