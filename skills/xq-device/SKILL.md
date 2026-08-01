---
name: xq-device
description: >-
  XQ agent-native device QE using upstream agent-device CLI. Use when installing
  QE tooling, driving or verifying apps on iOS/Android simulators or devices,
  or planning agent-device shell commands for ExperienceQuality apps.
license: MIT
compatibility: Requires Node.js >= 22.12 and network access to install agent-device via npm.
---

# xq-device

Router only. Private setup before using this skill:

```bash
agent-device --version
```

If that fails, install the pinned CLI with this skill's script (do not invent another install path):

```bash
bash scripts/install-cli.sh
```

The script lives next to this `SKILL.md` at `scripts/install-cli.sh`. From a clone of [ExperienceQuality/xq-qe-box](https://github.com/ExperienceQuality/xq-qe-box) before the skill is installed:

```bash
bash skills/xq-device/scripts/install-cli.sh
```

Or:

```bash
curl -fsSL https://raw.githubusercontent.com/ExperienceQuality/xq-qe-box/main/skills/xq-device/scripts/install-cli.sh | bash
```

Do **not** autonomously run `npm install -g agent-device@latest` or `npx -y agent-device@latest`. The install script pins versions; upgrades need explicit user approval.

Require `agent-device >= 0.20.0`. If older, stop and ask the user to re-run `scripts/install-cli.sh` or approve an exact-version bump.

Before your first device command or plan, read the smallest version-matched CLI guide that fits the task:

```bash
agent-device help manual-qa   # scripted/manual QA, acceptance checks
agent-device help validate    # code/runtime validation, stale build/daemon risk
agent-device help dogfood     # exploratory QA and evidence
agent-device help workflow    # full reference / mixed tasks
```

Additional topics when relevant: `debugging`, `react-native`, `react-devtools`, `cdp`, `tv`, `physical-device`, `ios-system-ui`, `macos`, `web`.

Default loop (from agent-device help): `open` → `snapshot -i` → mutate with `--settle` where supported → verify → `close`. Prefer latest `@refs` or durable selectors; do not pipe away raw CLI stdout while exploring (refs and hints live there).

Use this skill only to route into version-matched `agent-device help`. Do not invent a parallel command surface.
