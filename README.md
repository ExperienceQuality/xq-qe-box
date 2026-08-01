# xq-qe-box

ExperienceQuality Satellite for **agent-native QE**: skills (skills registry), install script, and room for future CLI/packages.

Wraps upstream [agent-device](https://github.com/callstack/agent-device) — this repo does not reimplement device automation.

**Hub satellite ref:** catalogue row + Ticket label [`satellite:xq-qe-box`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) · Spec [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Layout

```
skills/
  xq-mobile-auto-test/
    SKILL.md                 # Agent Skills frontmatter + instructions
    scripts/
      install-cli.sh         # pinned agent-device install (part of the skill)
packages/                    # reserved for future packages
cli/                         # reserved (add when needed)
```

This matches [`gh skill publish`](https://cli.github.com/manual/gh_skill_publish) discovery: `skills/*/SKILL.md`, with optional `scripts/` beside `SKILL.md` ([Agent Skills spec](https://agentskills.io/specification)).

## Install agent-device

```bash
# from repo root
bash skills/xq-mobile-auto-test/scripts/install-cli.sh

# or
curl -fsSL https://raw.githubusercontent.com/ExperienceQuality/xq-qe-box/main/skills/xq-mobile-auto-test/scripts/install-cli.sh | bash
```

Pin override: `AGENT_DEVICE_VERSION=0.20.3 bash skills/xq-mobile-auto-test/scripts/install-cli.sh`

Requires Node.js ≥ 22.12.

## Skills (`gh skill` / skills.sh)

Validate (no release):

```bash
gh skill publish --dry-run
```

Install / preview:

```bash
gh skill preview ExperienceQuality/xq-qe-box xq-mobile-auto-test
gh skill install ExperienceQuality/xq-qe-box xq-mobile-auto-test

# also works:
npx skills add ExperienceQuality/xq-qe-box --skill xq-mobile-auto-test
```

Publish (when ready): `gh skill publish --tag v0.1.0` — adds `agent-skills` topic and creates a release. Do not publish until explicitly asked.

## License

MIT
