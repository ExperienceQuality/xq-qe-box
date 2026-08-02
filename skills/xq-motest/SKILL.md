---
name: xq-motest
description: >-
  Automate iOS simulators or USB devices with the xq-motest CLI and DeviceKit
  WebSocket JSON-RPC. Use for map/@ref/tap loops, UI inspection, app launch,
  devicekit install/start, or when stdout must be agent-native JSON.
license: MIT
---

# xq-motest

Use the **`xq-motest`** binary from this module (`cli/xq-motest/swift`).
Build once, then drive DeviceKit with flat verbs and client-side `@eN` refs.

Default stdout is **compact JSON**. Use `--pretty` only for humans.

## Prerequisites

- macOS 13+, Xcode 15+, Swift 5.9+
- Booted simulator or trusted USB device (for live runs)

```bash
cd cli/xq-motest/swift
swift build -c release
export PATH="$PWD/.build/release:$PATH"
xq-motest --help
```

Offline verification (no DeviceKit): `bash cli/xq-motest/scripts/run-all.sh`

## Choose a mode

### Automate (default)

1. **Ensure DeviceKit is up** — by default RPC verbs auto-start the installed runner when `/health` is down (`--no-ensure-runtime` to disable). First-time setup:

   ```bash
   xq-motest devicekit install --sim
   xq-motest devicekit start --sim   # optional; map/tap will start if needed
   xq-motest health
   ```

   If `health` fails, run `devicekit status` and follow the `hint` in stderr.

2. **Launch the app under test** (when needed):

   ```bash
   xq-motest launch com.example.app
   ```

3. **Map → act → diff loop**:

   ```bash
   xq-motest map              # data: assigns @e1..@eN, saves ~/.xq-motest/
   xq-motest tap @e3          # action: {"ok":true}
   xq-motest diff map         # data: what changed since last map
   ```

4. After UI-changing actions, run **`map` again** before reusing `@eN` refs.

Read [agent loop](references/agent-loop.md) for response tiers, env vars, and real-device notes.

### Inspect

- `xq-motest dump` — raw `device.dump.ui` (data tier)
- `xq-motest rpc --method device.info` — escape hatch (data tier)
- `xq-motest screenshot /tmp/screen.png` — action tier; file on disk, stdout `{"ok":true}`

### Lifecycle only

```bash
xq-motest devicekit status
xq-motest devicekit install --sim [--device UDID]
xq-motest devicekit start --sim [--device UDID]
```

Real device install requires `--provisioning-profile PATH`. See module README.

## Non-negotiable rules

- **Positional-first hot path:** `tap @e3`, `type @e2 hello`, `screenshot /tmp/x.png` — avoid `--` on common verbs.
- **Action vs data:** `tap`, `type`, `launch`, `screenshot` → `{"ok":true}` only. `map`, `diff map`, `dump`, `rpc`, `health` → full `result`.
- **Do not parse discarded RPC bodies** on action calls; re-`map` when you need UI state.
- **State dir:** `~/.xq-motest/` (or `XQ_MOTEST_STATE_DIR`). Refs invalidate after UI changes — always re-map.
- **No MobileCLI** — this CLI owns install/start; do not substitute another control plane.
- **Globals via env** when scripting: `XQ_MOTEST_BASE_URL`, `XQ_MOTEST_TIMEOUT`, `XQ_MOTEST_DEVICE`.

## Install this skill

From a consumer repo with GitHub CLI:

```bash
gh skill install OWNER/REPO xq-motest --agent <host>
```

The skill root is the directory containing this `SKILL.md`. Module source and
build instructions remain in `cli/xq-motest/README.md`.
