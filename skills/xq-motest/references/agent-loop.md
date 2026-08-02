# Agent loop reference

## Response tiers

| Tier | Commands | stdout |
| --- | --- | --- |
| **action** | `tap`, `type`, `launch`, `foreground`, `screenshot` | `{"ok":true}` |
| **data** | `map`, `diff map`, `dump`, `rpc`, `health`, `devicekit status` | envelope with `result` |

Failures always include `error`, `exitCode`, and optional `hint`.

## Typical session

```bash
# DeviceKit runner already installed by agent-host infra
xq-motest devicekit start --sim --device <UDID>
xq-motest health
xq-motest launch com.example.app
xq-motest map
xq-motest tap @e3
xq-motest diff map
xq-motest map                    # refresh refs after tap
```

## Environment

| Variable | Default |
| --- | --- |
| `XQ_MOTEST_BASE_URL` | `http://127.0.0.1:12004` |
| `XQ_MOTEST_TIMEOUT` | `30` (bounds WS RPC, health wait, ensure; CLI `--timeout`) |
| `XQ_MOTEST_STATE_DIR` | `~/.xq-motest` |
| `XQ_MOTEST_DEVICE` | _(optional UDID)_ |

## Simulator vs real device

| Target | Infra | CLI start |
| --- | --- | --- |
| Simulator | Install DeviceKit `.app` on sim | `devicekit start --sim --device UDID` |
| Real device | Install signed DeviceKit `.ipa` on device | `devicekit start --device UDID` |

Start uses `simctl launch` (sim) or `xcodebuild test-without-building` (device).

## Troubleshooting

| Symptom | Try |
| --- | --- |
| Connection refused | `devicekit start --sim` then `health` (or rely on auto-start) |
| Unknown `@eN` | `map` first |
| Stale refs after tap | `map` again before next `@eN` |
| Runner not found | Install DeviceKit runner via agent-host infra, then `devicekit start` |

## Verify without live DeviceKit

```bash
bash cli/xq-motest/scripts/run-all.sh
```
