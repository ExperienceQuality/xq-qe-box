# Quality glossary

Use these terms in ephemeral strategy/plans and when naming sizes/stages. Prefer this vocabulary over vague “unit / integration / e2e” alone.

| Term | Meaning | Avoid |
| --- | --- | --- |
| **Asset** | A shippable (iOS app, Android app, web app, one microservice). Strategy scope is per asset. | Product, Satellite, “the system” (when you mean one shippable) |
| **Component** | A fine-grained unit *inside* an asset: screen, button, fragment, model, service, API handler, service integration, … | Satellite, whole app (use asset) |
| **Capability** | What a component can / would do (functional behavior). | Feature (when you mean a single component behavior) |
| **Attribute** | Quality lens on a capability: always includes **correctness**; also accessibility, performance, security, and other NFRs. | “Non-functional” as a dump category without naming the attribute |
| **Spot** | One cell: `(component, capability, attribute)`. The unit of coverage intent. | Test case (a spot may need one or many tests) |
| **Small / medium / large** | Google-style **test sizes** (resource + network constraints). See [`principles.md`](principles.md). Not synonyms for unit/integration/e2e scope. | Using “e2e” when you mean large size |
| **Hermetic** | A test owns setup, execute, and teardown; assumes as little as possible about shared outside state. | “Isolated” without saying what is faked vs live |
| **Presubmit** | PR / pre-merge gate: **small + medium** for affected assets. | Running large E2E on every PR by default |
| **Post-submit** | After merge: broader medium + **large** multi-asset / live E2E lanes. | Blocking every merge on full product E2E |
| **Ephemeral plan** | Spot → size → stage notes in a PR or Ticket body. Not committed as a lasting matrix file. | Requiring `docs/quality/` binders in Satellites |
