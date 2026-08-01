# xq-qe-box

Org-owned monorepo for agent-native QE tooling used across ExperienceQuality Satellites.

**Hub:** catalogue — [`docs/satellites.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) (`satellite:xq-qe-box`) · Spec — [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Language

**xq-qe-box**:
The Satellite that stores skills (skills registry), the `xq-motest` CLI, install helpers, and related packages.
_Avoid_: Hub (this is not the Agent Context Hub)

**xq-motest**:
XQ’s agent-native iOS CLI under `cli/xq-motest/`. Talks **directly to DeviceKit** (JSON-RPC). Cloned from `xq-versastacks` `xq-ios-act-cli` and renamed.
_Avoid_: xq-ios-act (old name); agent-device (different stack)

**DeviceKit**:
On-device XCUITest JSON-RPC runtime (`devicekit-ios`) that `xq-motest` drives. Not the Callstack AgentDeviceRunner.
_Avoid_: agent-device helper, MobileCLI (optional; xq-motest installs DeviceKit itself)

**agent-device**:
Upstream Callstack CLI (CLI → daemon → native helper). Still available via skill `xq-mobile-auto-test` for comparison / optional use; not the primary XQ motest path.
_Avoid_: Calling agent-device “xq-motest”

**xq-motest (skill)**:
Agent Skill under `skills/xq-motest/` for the DeviceKit-direct CLI loop.
_Avoid_: Duplicating full manuals when CLI `--help` / README suffice

**xq-mobile-auto-test**:
Skill that installs/routs **agent-device** (separate from `xq-motest`).
_Avoid_: Using this skill when the task is the DeviceKit/`xq-motest` path

**Skill**:
A folder under `skills/<name>/` with `SKILL.md` (Agent Skills format) and optional `scripts/`. Validated with `gh skill publish --dry-run`.
_Avoid_: Full command cookbooks in SKILL.md when the CLI owns the contract
