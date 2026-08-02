---
name: quality-controlling
description: >-
  Apply quality controlling rules: PR vs post-submit vs release gates, flake
  quarantine, and skips with owner/expiry. Use when setting CI gates, merging
  with failures, or quarantining tests.
license: MIT
---

# quality-controlling

## Load standards (local references)

1. [references/principles.md](references/principles.md) (§ Stages)
2. Template: [references/test-controlling.md](references/test-controlling.md)

## Default gates

| Stage | Must pass | Blocks merge? |
| --- | --- | --- |
| Presubmit | Declared small + medium | yes |
| Post-submit | Declared large / broader medium | no by default |
| Release | Curated smoke (if used) | blocks promote |

## Quarantine / skip

- Every quarantine or skip needs **reason, owner, expiry**.
- Quarantined tests **do not** count as covering spots.
- Prefer fix or delete over permanent skip.

## Procedure

1. Fill the controlling template for the change.
2. Paste into PR/Ticket.
3. If the user wants large on PR: require explicit exception + owner; do not silently expand the default gate.

## Refuse

- Merging with failing non-quarantined presubmit small/medium
- Infinite retry-as-green without quarantine
- Treating post-submit large red as “not our problem” with no owner
