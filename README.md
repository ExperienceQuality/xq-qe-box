# xq-qe-box

ExperienceQuality Satellite for **agent-native QE**: skills (skills registry), install script, and room for future CLI/packages.

Wraps upstream [agent-device](https://github.com/callstack/agent-device) — this repo does not reimplement device automation.

**Hub satellite ref:** catalogue row + Ticket label [`satellite:xq-qe-box`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) · Spec [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Layout

```
skills/<skill-name>/SKILL.md   # discovered by npx skills / skills.sh
scripts/install-cli.sh         # pinned agent-device install
packages/                      # reserved for future packages
cli/                           # reserved (add when needed)
```

## Install agent-device

```bash
bash scripts/install-cli.sh

# or
curl -fsSL https://raw.githubusercontent.com/ExperienceQuality/xq-qe-box/main/scripts/install-cli.sh | bash
```

Pin override: `AGENT_DEVICE_VERSION=0.20.3 bash scripts/install-cli.sh`

Requires Node.js ≥ 22.12.

## Skills (GitHub / skills.sh registry)

There is **no separate publish step**. A public GitHub repo is the source; [`npx skills`](https://github.com/vercel-labs/skills) discovers `SKILL.md` files under known paths ([Agent Skills format](https://agentskills.io/)).

### Required shape

```
skills/
  xq-device/
    SKILL.md          # required: YAML frontmatter + instructions
    scripts/          # optional
    references/       # optional
    assets/           # optional
```

Each skill is a **directory** whose name matches frontmatter `name`, containing `SKILL.md` with at least:

```yaml
---
name: xq-device
description: When to use this skill (shown in discovery lists)
---
```

Discovery also accepts catalog nesting (`skills/<category>/<name>/SKILL.md`) and a root-level `SKILL.md` (avoid root `SKILL.md` in a monorepo — it can treat the whole repo as one skill).

### Install / list

```bash
npx skills add ExperienceQuality/xq-qe-box --list
npx skills add ExperienceQuality/xq-qe-box --skill xq-device
```

Listing on [skills.sh](https://skills.sh) follows installs/indexing of the public repo; consumers can always install via owner/repo shorthand above.

## License

MIT
