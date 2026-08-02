# xq-qe-box

ExperienceQuality Satellite for **agent-native QE**: DeviceKit-direct CLI (`xq-motest`), skills, and optional agent-device tooling.

**Hub satellite ref:** [`satellite:xq-qe-box`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/satellites.md) · Spec [`docs/specs/xq-qe-box.md`](https://github.com/ExperienceQuality/xq-hub/blob/main/docs/specs/xq-qe-box.md)

## Layout

```
cli/xq-motest/                 # Swift CLI → DeviceKit JSON-RPC (primary)
skills/xq-motest/              # skill for xq-motest
skills/xq-mobile-auto-test/    # optional: pinned agent-device install + router
packages/                      # reserved
```

## Primary: xq-motest (DeviceKit)

```bash
cd cli/xq-motest/swift
swift build -c release
export PATH="$PWD/.build/release:$PATH"

# DeviceKit runner must already be installed by agent-host infra
xq-motest devicekit start --sim --device <UDID>
xq-motest map
xq-motest tap @e3
```

Docs: [`cli/xq-motest/README.md`](cli/xq-motest/README.md) · skill: `gh skill install ExperienceQuality/xq-qe-box xq-motest` · ADR-0001 (runner preinstalled)

## Optional: agent-device

```bash
bash skills/xq-mobile-auto-test/scripts/install-cli.sh
gh skill install ExperienceQuality/xq-qe-box xq-mobile-auto-test
```

## Skills validation

```bash
gh skill publish --dry-run
```

## License

MIT (XQ code). DeviceKit itself is upstream Mobile Next — respect its license when redistributing runner artifacts.
