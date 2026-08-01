# xq-qe-box

ExperienceQuality Satellite for **agent-native QE**: skills (skills registry), install script, `xq-qe` wrapper CLI, and future packages.

Wraps upstream [agent-device](https://github.com/callstack/agent-device) — this repo does not reimplement device automation.

Hub Spec: [ExperienceQuality/xq-hub `docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Layout

```
packages/xq-qe/     # wrapper CLI (bin: xq-qe)
skills/xq-qe/       # skills registry skill (thin router)
scripts/            # install-cli.sh (agent-device + xq-qe)
```

## Install both CLIs

```bash
# from a clone
bash scripts/install-cli.sh

# or remote
curl -fsSL https://raw.githubusercontent.com/ExperienceQuality/xq-qe-box/main/scripts/install-cli.sh | bash
```

Pin override: `AGENT_DEVICE_VERSION=0.20.3 bash scripts/install-cli.sh`

Requires Node.js ≥ 22.12.

## Skill

```bash
npx skills add ExperienceQuality/xq-qe-box --skill xq-qe
```

## Quick check

```bash
xq-qe doctor
agent-device help workflow
```

## License

MIT
