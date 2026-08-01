# xq-qe-box

Org-owned monorepo for agent-native QE tooling used across ExperienceQuality Satellites.

## Language

**xq-qe-box**:
The Satellite that stores skills (skills registry), install scripts, the `xq-qe` wrapper CLI package, and future QE packages.
_Avoid_: motest, parallel mobile-control CLI, Hub (this is not the Agent Context Hub)

**xq-qe**:
The wrapper CLI binary/package published from `packages/xq-qe`. Day one: doctor/help and install pairing with upstream `agent-device`. Not a second device-automation engine.
_Avoid_: agent-device (upstream product name — keep distinct), motest

**agent-device**:
Upstream Callstack CLI that inspects, controls, and verifies apps on device/simulator targets. Installed alongside `xq-qe` by `scripts/install-cli.sh`. Agents read its installed `help` topics for command contracts.
_Avoid_: Our CLI (say xq-qe or agent-device explicitly)

**Skill (xq-qe)**:
Thin router under `skills/xq-qe` for skill-aware agents. Points at `xq-qe doctor` and version-matched `agent-device help …`. Does not duplicate the CLI manual.
_Avoid_: Full command cookbook in SKILL.md
