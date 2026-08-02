# Template: ephemeral asset test strategy

Paste into a PR or Ticket. Do **not** commit a lasting matrix unless a Satellite explicitly chooses to later.

## Context

- **Satellite:**
- **Asset:** (shippable id, e.g. `ios-app`, `api-orders`)
- **Change summary:**

## Spots in scope

| Component | Capability | Attribute | In / out / deferred | Small | Medium | Large | ROI note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| | | correctness | in | ☐ | ☐ | ☐ | Prefer smallest honest size |
| | | | | ☐ | ☐ | ☐ | |

Rules:

- Attribute always named (include `correctness`).
- Check the smallest size that can cover the spot; add larger only if needed.
- Large ⇒ multi-asset / live E2E — justify why medium localhost is insufficient.
