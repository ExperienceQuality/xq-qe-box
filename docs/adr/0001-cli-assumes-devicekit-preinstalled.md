# CLI assumes DeviceKit runner is preinstalled

Agent hosts that invoke `xq-motest` must already have the DeviceKit runner (`.app` / `.ipa`) available and installed on the target test devices. The CLI does not ship install/resign shell scripts and does not own DeviceKit provisioning — it assumes infra is set up and only performs Session traffic (health + JSON-RPC) plus optional start of an already-installed runner, failing clearly when the runner is missing or unreachable.

**Status:** accepted

**Considered options:** keep clone-era `scripts/devicekit/*` + `devicekit install` in-CLI (rejected — duplicates infra, fights SPM, wrong ownership for LLM agent environments); embed runner artifacts in the package (rejected — packaging and signing burden).

**Consequences:** `DeviceKitRuntime` owns ensure/start/status/health; Motest exposes `devicekit start|status` only. Skills and README point operators at infra, not CLI install verbs. Hub Spec: `xq-motest-deep-modules` / Ticket #8.
