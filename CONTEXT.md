# xq-qe-box

Org-owned monorepo for agent-native QE tooling used across ExperienceQuality Satellites.

## Language

**xq-qe-box**:
The Satellite that stores skills (skills registry), install scripts, and future QE CLI/packages.
_Avoid_: motest, parallel mobile-control CLI, Hub (this is not the Agent Context Hub)

**agent-device**:
Upstream Callstack CLI that inspects, controls, and verifies apps on device/simulator targets. Installed by `scripts/install-cli.sh`. Agents read its installed `help` topics for command contracts.
_Avoid_: Our CLI (say agent-device or a future package name explicitly)

**Skill**:
A folder under `skills/<name>/` with `SKILL.md` (Agent Skills format). Published by being on the public GitHub repo — discovered via `npx skills add ExperienceQuality/xq-qe-box`. Thin routers point at install + version-matched `agent-device help …`.
_Avoid_: Full command cookbook in SKILL.md; separate npm “publish” for skills
