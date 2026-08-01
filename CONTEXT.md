# xq-qe-box

Org-owned monorepo for agent-native QE tooling used across ExperienceQuality Satellites.

**Hub:** catalogue — [`docs/satellites.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) (`satellite:xq-qe-box`) · Spec — [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Language

**xq-qe-box**:
The Satellite that stores skills (skills registry), install scripts, and future QE CLI/packages.
_Avoid_: motest, parallel mobile-control CLI, Hub (this is not the Agent Context Hub)

**agent-device**:
Upstream Callstack CLI that inspects, controls, and verifies apps on device/simulator targets. Installed by `skills/xq-mobile-auto-test/scripts/install-cli.sh`. Agents read its installed `help` topics for command contracts.
_Avoid_: Our CLI (say agent-device or a future package name explicitly)

**xq-mobile-auto-test**:
The day-one Agent Skill under `skills/xq-mobile-auto-test/` — thin router to the bundled install script and version-matched `agent-device help …`.
_Avoid_: xq-device (old name)

**Skill**:
A folder under `skills/<name>/` with `SKILL.md` (Agent Skills format) and optional `scripts/`. Validated/published with `gh skill publish`.
_Avoid_: Full command cookbook in SKILL.md; install scripts living outside the skill folder
