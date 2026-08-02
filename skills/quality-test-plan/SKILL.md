---
name: quality-test-plan
description: >-
  Turn an ephemeral spot strategy into a test plan: suites mapped to
  small/medium/large and presubmit vs post-submit vs release, plus localhost
  doubles for medium tests. Use when wiring CI or deciding what runs when.
license: MIT
---

# quality-test-plan

## Load standards (local references)

1. [references/principles.md](references/principles.md)
2. Template: [references/asset-test-plan.md](references/asset-test-plan.md)

## Procedure

1. Start from spots already listed (run `quality-asset-strategy` first if missing).
2. Group spots into **suites/targets** with an explicit **size**.
3. Assign **stage**:
   - presubmit → small + medium (affected assets)
   - post-submit → large and broader medium
   - release → optional curated large smoke
4. For medium+: name **doubles/env** (stubserver, stub Kafka, DB, …) and confirm **localhost** (or document why not — then it is large).
5. Paste plan into PR/Ticket. Do not require a committed Satellite quality binder.

## Refuse

- Large suites on the default PR gate without explicit product exception
- Medium tests that call remote production/staging APIs without reclassifying as large
