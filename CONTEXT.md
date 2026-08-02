# xq-qe-box

Org-owned monorepo for agent-native QE tooling used across ExperienceQuality Satellites.

**Hub:** catalogue — [`docs/satellites.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) (`satellite:xq-qe-box`) · Spec — [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md) · Deepenings — [`docs/specs/xq-motest-deep-modules.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-motest-deep-modules.md)

## Language

**xq-qe-box**:
The Satellite that stores skills (skills registry), the `xq-motest` CLI, and related packages.
_Avoid_: Hub (this is not the Agent Context Hub)

**xq-motest**:
XQ’s agent-native iOS CLI under `cli/xq-motest/`. Talks **directly to DeviceKit** (JSON-RPC). Cloned from `xq-versastacks` `xq-ios-act-cli` and renamed. Assumes the DeviceKit runner is already installed by the agent host environment.
_Avoid_: xq-ios-act (old name); agent-device (different stack); install-DeviceKit CLI

**DeviceKit**:
On-device XCUITest JSON-RPC runtime (`devicekit-ios`) that `xq-motest` drives. Not the Callstack AgentDeviceRunner. The runner (`.app` / `.ipa`) is provided and installed by infra before `xq-motest` runs.
_Avoid_: agent-device helper; MobileCLI; “CLI installs DeviceKit”

**DeviceKitRuntime**:
The Motest module responsible for “is DeviceKit ready for this Session?” — health and start of an already-installed runner. Not install or resign.
_Avoid_: ShellScripts, ModulePaths for DeviceKit, devicekit install

**Session**:
One agent-driven interaction with DeviceKit through `xq-motest` (map, act, assert loop against an app under test).
_Avoid_: daemon session (agent-device); vague “connection”

**CommandRunner**:
The Motest module that is the Session command surface — every mutation/query agents need goes through it; the executable only parses argv and maps errors.
_Avoid_: MotestCommand as the place business logic lives

**agent-device**:
Upstream Callstack CLI (CLI → daemon → native helper). Still available via skill `xq-mobile-auto-test` for comparison / optional use; not the primary XQ motest path.
_Avoid_: Calling agent-device “xq-motest”

**xq-motest (skill)**:
Agent Skill under `skills/xq-motest/` for the DeviceKit-direct CLI loop.
_Avoid_: Duplicating full manuals when CLI `--help` / README suffice

**xq-mobile-auto-test**:
Skill that installs/routs **agent-device** (separate from `xq-motest`).
_Avoid_: Using this skill when the task is the DeviceKit/`xq-motest` path

**quality-\*** (skills):
Agent Skills under `skills/quality-*/` that enforce Hub org testing standards (sizes, hermeticity, spot coverage). Docs are vendored in each skill’s `references/`. Install with `gh skill install ExperienceQuality/xq-qe-box quality-…`. Editorial source: Hub [`quality/`](https://github.com/ExperienceQuality/xq-hub/tree/main/quality).
_Avoid_: Satellite-local `docs/quality/` binders; curling Hub at runtime for these docs

**Skill**:
A folder under `skills/<name>/` with `SKILL.md` (Agent Skills format) and optional `scripts/` / `references/`. Validated with `gh skill publish --dry-run`.
_Avoid_: Full command cookbooks in SKILL.md when the CLI owns the contract
