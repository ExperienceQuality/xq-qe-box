---
name: xq-qe
description: >-
  XQ agent-native QE via the xq-qe wrapper and upstream agent-device CLI.
  Use when installing QE tooling, running xq-qe doctor, or driving/verifying
  apps on iOS/Android simulators or devices with agent-device commands.
---

# xq-qe

Router only. Private setup before using this skill:

```bash
xq-qe --version
xq-qe doctor
```

If `xq-qe` or `agent-device` is missing, stop and tell the user to run the install script from [ExperienceQuality/xq-qe-box](https://github.com/ExperienceQuality/xq-qe-box):

```bash
curl -fsSL https://raw.githubusercontent.com/ExperienceQuality/xq-qe-box/main/scripts/install-cli.sh | bash
```

Or, from a clone: `bash scripts/install-cli.sh`.

Do **not** autonomously run `npm install -g agent-device@latest` or `npx -y agent-device@latest`. The install script pins versions; upgrades need explicit user approval.

Require `agent-device >= 0.20.0` (enforced by `xq-qe doctor`). If doctor fails on version, stop and ask the user to re-run the install script or approve an exact-version bump.

Before your first device command or plan, read the smallest version-matched CLI guide that fits the task:

```bash
agent-device help manual-qa   # scripted/manual QA, acceptance checks
agent-device help validate    # code/runtime validation, stale build/daemon risk
agent-device help dogfood     # exploratory QA and evidence
agent-device help workflow    # full reference / mixed tasks
```

Additional topics when relevant: `debugging`, `react-native`, `react-devtools`, `cdp`, `tv`, `physical-device`, `ios-system-ui`, `macos`, `web`.

Default loop (from agent-device help): `open` → `snapshot -i` → mutate with `--settle` where supported → verify → `close`. Prefer latest `@refs` or durable selectors; do not pipe away raw CLI stdout while exploring (refs and hints live there).

Use this skill only to route into `xq-qe doctor` and version-matched `agent-device help`. Do not invent a parallel command surface.
