# Agent loop reference

## Response tiers

| Tier | Commands | stdout |
| --- | --- | --- |
| **action** | `tap`, `type`, `launch`, `foreground`, `screenshot` | `{"ok":true}` |
| **data** | `map`, `diff map`, `dump`, `rpc`, `health`, `devicekit status` | envelope with `result` |

Failures always include `error`, `exitCode`, and optional `hint`.

## Typical session

```bash
xq-motest devicekit install --sim
xq-motest devicekit start --sim
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
| `XQ_MOTEST_TIMEOUT` | `30` |
| `XQ_MOTEST_STATE_DIR` | `~/.xq-motest` |
| `XQ_MOTEST_DEVICE` | _(optional UDID)_ |

## Simulator vs real device

| Target | Install | Start |
| --- | --- | --- |
| Simulator | `devicekit install --sim` | `devicekit start --sim` |
| Real device | `install --device UDID --provisioning-profile PATH` | `devicekit start --device UDID` |

Real device: unsigned IPA from devicekit-ios releases → Swift resign → `devicectl`.
Start uses `xcodebuild test-without-building` (Xcode-only; no iproxy/go-ios).

## Troubleshooting

| Symptom | Try |
| --- | --- |
| Connection refused | `devicekit start --sim` then `health` (or rely on auto-start after install) |
| Unknown `@eN` | `map` first |
| Stale refs after tap | `map` again before next `@eN` |
| Runner not installed | `devicekit install --sim` |

## Verify without live DeviceKit

```bash
bash cli/xq-motest/scripts/run-all.sh
```
