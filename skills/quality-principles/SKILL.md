---
name: quality-principles
description: >-
  Apply ExperienceQuality quality standards: Google-style test sizes,
  hermeticity, and coverage as component×capability×attribute spots. Use for
  any testing, QA, coverage, or CI-stage discussion before writing or changing
  tests.
license: MIT
---

# quality-principles

Read these files next to this skill (do not fetch Hub over the network):

- [references/principles.md](references/principles.md) — binding rules
- [references/glossary.md](references/glossary.md) — vocabulary
- [references/README.md](references/README.md) — pack index
- [references/templates/](references/templates/) — ephemeral plan shapes

## Non-negotiable

1. **Coverage** = spots `(component, capability, attribute)`. Always name **correctness** as an attribute when functional.
2. **Sizes** = Google constraints (small / medium / large) — not synonyms for unit/integration/e2e.
3. **Small + medium** stay inside one **asset**; **large** = live multi-component / multi-asset E2E.
4. **Presubmit** = small+medium; **post-submit** = large (+ broader). Do not put large on every PR by default.
5. **No** durable `docs/quality/` binder required in Satellites. Ephemeral plans in PR/Ticket only.
6. Prefer the **smallest** size that honestly covers each spot.

## Related skills

- `quality-asset-strategy` — enumerate spots + size/ROI
- `quality-test-plan` — suites ↔ stages
- `quality-reporting` — evidence expectations
- `quality-controlling` — gates, quarantine, skips
