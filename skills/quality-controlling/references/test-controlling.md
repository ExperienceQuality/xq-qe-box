# Template: controlling for this change

## Gates

| Stage | What must pass | Blocks merge? | Blocks release? |
| --- | --- | --- | --- |
| Presubmit | Listed small + medium | yes | n/a |
| Post-submit | Listed large / broader medium | no (default) | optional |
| Release | Curated smoke (if any) | n/a | yes / no |

## Quarantine / skip

| Test / suite | Reason | Owner | Expiry |
| --- | --- | --- | --- |
| | | | |

Quarantined tests do **not** count as covering their spots until removed from quarantine.
