---
name: quality-reporting
description: >-
  Define test reporting evidence for a change: artifacts, suite identity, and
  mapping failures back to coverage spots. Use when adding CI summaries,
  junit/artifacts, or explaining what “green” means.
license: MIT
---

# quality-reporting

## Load standards (local references)

1. [references/principles.md](references/principles.md)
2. Template: [references/test-reporting.md](references/test-reporting.md)

## Procedure

1. For each suite in the plan, specify **artifacts** (logs, junit, screenshots, traces).
2. Require a stable **suite name/id** in CI output.
3. Explain how a failure maps to the **spots** named in the ephemeral strategy (even if mapping is “suite → spot list”).
4. Include Ticket/PR correlation ids in the ephemeral reporting section.
5. Paste into PR/Ticket; do not invent a separate reporting product requirement unless asked.

## Refuse

- “CI passed” with no suite identity or artifacts for medium/large
- Coverage % as the only report of what was tested
