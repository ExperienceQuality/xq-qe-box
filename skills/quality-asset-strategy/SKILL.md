---
name: quality-asset-strategy
description: >-
  Author an ephemeral per-asset test strategy: component×capability×attribute
  spots, in/out/deferred, and small/medium/large ROI choices for a PR or Ticket.
  Use when planning what to test for a shippable asset.
license: MIT
---

# quality-asset-strategy

## Load standards (local references)

1. [references/principles.md](references/principles.md)
2. [references/glossary.md](references/glossary.md)
3. Template: [references/asset-test-strategy.md](references/asset-test-strategy.md)

## Procedure

1. Identify **Satellite** and **asset** (shippable).
2. List **components** touched or at risk (screens, handlers, models, integrations, …).
3. For each component, name **capabilities** and **attributes** (include `correctness`).
4. Mark each spot **in / out / deferred**.
5. For each **in** spot, choose smallest honest **size** (small → medium → large). Justify any large.
6. Paste the filled template into the **PR or Ticket body** — do not create Satellite `docs/quality/` files unless the user explicitly asks.

## Refuse

- Strategies that call UI E2E “small”
- Large tests without saying which live components are required
- Line-% goals as a substitute for spots
