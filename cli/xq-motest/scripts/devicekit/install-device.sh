#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: install-device.sh IPA UDID" >&2
  exit 1
fi

IPA="$1"
UDID="$2"

if xcrun devicectl device install app --device "$UDID" "$IPA" >/dev/null 2>&1; then
  exit 0
fi

if command -v ios >/dev/null 2>&1; then
  ios install --path "$IPA" --udid "$UDID" >/dev/null
  exit 0
fi

echo "device install requires Xcode devicectl" >&2
exit 1
