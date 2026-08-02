# Quality principles

**Status:** Normative for ExperienceQuality agents and CI design.  
**Anchors:** [SWE Book ch. 11 — Testing Overview](https://abseil.io/resources/swe-book/html/ch11.html) (sizes, hermeticity); coverage as a **matrix of spots**, not a global line-% gate. TAP-like *policy* (presubmit vs post-submit) — see [google-tap research](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/ideas/google-tap.md) — not Google’s internal TAP product.

---

## 1. Coverage = spots

\[
\text{coverage intent} = \text{components} \times \text{capabilities} \times \text{attributes}
\]

Each cell is a **spot**. Always treat **correctness** as an attribute (3D model). Other attributes include accessibility, performance, security, etc.

1. Enumerate in-scope spots for the change (or asset under discussion).
2. For each in-scope spot, choose the **smallest** test size that can honestly cover it (ROI).
3. A spot may need a **combination** of sizes; prefer small/medium inside the asset before large.

There is **no required durable matrix file**. The spot list for a change is ephemeral (PR/Ticket). Line/branch % may be a CI signal for small tests; it is not the definition of coverage.

---

## 2. Test sizes (constraints)

| Size | Allowed | Forbidden |
| --- | --- | --- |
| **Small** | Single process (prefer single thread); doubles instead of real DB/server | Other processes, real DB/third-party binary as SUT deps, network, sleep-as-sync |
| **Medium** | Multi-process, threads, blocking calls, network to **localhost only** (e.g. stubs/Testcontainers on loopback) | Network to remote machines |
| **Large** | Multi-machine / real deployed envs / device farms / multi-asset live integration | — (use sparingly) |

### Asset boundary

- **Small and medium** cover behavior **within one asset** (local doubles, localhost stubs, in-process fakes).
- **Large** requires **more live components integrated** as an E2E flow (other assets, shared staging, real devices/backends as needed).

### Hermeticity

All sizes **strive** to be hermetic: own setup, execute, teardown; do not rely on shared mutable DBs or test order. Large tests may weaken isolation — document live deps in the ephemeral plan.

---

## 3. Stages (controlling)

| Stage | Runs | Gate |
| --- | --- | --- |
| **Presubmit / PR** | Small + medium for **affected** assets | Must be green |
| **Post-submit** | Broader medium + **large** E2E lanes | Fix-forward or rollback; does not block every PR by default |
| **Release** (optional) | Curated large smoke for the product | Blocks promote/ship |

Flakes: quarantine with owner + expiry; quarantined tests do not count as covering a spot. Skips need owner + reason + expiry (NOTAP-style discipline).

---

## 4. Conformance (no Satellite quality binder)

Satellites **do not** maintain `docs/quality/` strategy files. Conformance means:

1. Agent used the relevant **`quality-*` skills** from `xq-qe-box`.
2. PR/Ticket contains an **ephemeral plan**: spots → size → stage.
3. Tests in code/CI are declared with **size** and run in the correct **stage**.

Skills install:

```bash
gh skill install ExperienceQuality/xq-qe-box quality-principles
gh skill install ExperienceQuality/xq-qe-box quality-asset-strategy
gh skill install ExperienceQuality/xq-qe-box quality-test-plan
gh skill install ExperienceQuality/xq-qe-box quality-reporting
gh skill install ExperienceQuality/xq-qe-box quality-controlling
```
