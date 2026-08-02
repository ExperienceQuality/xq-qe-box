# xq-motest

Agent-native iOS CLI for DeviceKit over WebSocket/HTTP JSON-RPC.

Cloned from `xq-versastacks` `xq-ios-act-cli` and renamed for Satellite `xq-qe-box`. See [ORIGIN.md](ORIGIN.md).

## Prerequisites

- macOS 13+
- Xcode 15+ (for `xcodebuild` / `simctl` when starting a runner)
- Swift 5.9+
- **DeviceKit runner already installed** on the target sim/device by agent-host infra (`.app` / `.ipa`). This CLI does not install or resign the runner (ADR-0001).

## Install (development)

```bash
cd cli/xq-motest/swift
swift build -c release
.build/release/xq-motest --help
```

## Agent loop

```bash
# Infra has already installed the DeviceKit runner on the device.
xq-motest devicekit start --sim --device <UDID>   # optional; RPC verbs auto-start when needed
xq-motest health
xq-motest launch com.example.app
xq-motest map
xq-motest tap @e3
xq-motest diff map
```

### Real device (Apple-only)

Requires the **presigned IPA already installed**, plus a same-build **Products** sidecar on the Mac
(`.xctestrun` + `Release-iphoneos/*.app` from `build-for-testing` — not the DeviceKit git tree).

```bash
export XQ_MOTEST_DEVICEKIT_PRODUCTS=/path/to/Products
export XQ_MOTEST_BASE_URL=http://<device-wifi-ip>:12004

xq-motest devicekit start --device <UDID> \
  --products-dir "$XQ_MOTEST_DEVICEKIT_PRODUCTS" \
  --base-url "$XQ_MOTEST_BASE_URL" \
  --timeout 120

xq-motest health --base-url "$XQ_MOTEST_BASE_URL" --pretty
xq-motest map --device <UDID> --base-url "$XQ_MOTEST_BASE_URL" --pretty
```

Start runs `xcodebuild test-without-building` against that products xctestrun (keeps
`testRunAutomation` alive). No go-ios / `iproxy` when DeviceKit binds `0.0.0.0` and
you point `--base-url` at the phone’s Wi‑Fi IP.

## Commands

| Command | Tier | Notes |
| --- | --- | --- |
| `health` | data | HTTP `/health` probe |
| `map` | data | `device.dump.ui` → `@eN` refs |
| `diff map` | data | local diff vs previous map |
| `tap` | action | `@eN` or `X Y` |
| `type` | action | `[@eN] TEXT` |
| `screenshot PATH` | action | writes file, stdout `{"ok":true}` |
| `launch BUNDLE_ID` | action | app under test |
| `foreground` | action | |
| `dump` | data | raw `device.dump.ui` |
| `rpc METHOD [PARAMS_JSON]` | data | escape hatch |
| `devicekit start/status` | mixed | start already-installed runner; status |

## Environment

| Variable | Purpose |
| --- | --- |
| `XQ_MOTEST_BASE_URL` | DeviceKit HTTP base (default `http://127.0.0.1:12004`; use device Wi‑Fi IP on hardware) |
| `XQ_MOTEST_TIMEOUT` | Bound for WebSocket RPC, health waits, and ensure (seconds; also `--timeout`) |
| `XQ_MOTEST_STATE_DIR` | State directory (default `~/.xq-motest`) |
| `XQ_MOTEST_DEVICE` | UDID override |
| `XQ_MOTEST_DEVICEKIT_PRODUCTS` | Products dir for real-device start (also `--products-dir`) |

`--no-ensure-runtime` disables auto-start before RPC verbs (default: auto-start via DeviceKitRuntime when `/health` is down).

## Verify

```bash
bash cli/xq-motest/scripts/run-all.sh
```

## Agent skill

```bash
gh skill install ExperienceQuality/xq-qe-box xq-motest
# or: npx skills add ExperienceQuality/xq-qe-box --skill xq-motest
```

Source: [`skills/xq-motest/SKILL.md`](../../skills/xq-motest/SKILL.md).

## DeviceKit runtime (infra-owned install)

The agent host must install the DeviceKit runner before invoking this CLI. `xq-motest` only starts an installed runner and talks JSON-RPC.

```bash
xcrun simctl boot <UDID>   # if not already booted
xq-motest devicekit start --sim --device <UDID>
xq-motest health
```

If the runner is missing, errors hint at infra — not a CLI install verb.
