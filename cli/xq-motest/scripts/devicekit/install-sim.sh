#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: install-sim.sh ARTIFACT.zip|ARTIFACT.app UDID" >&2
  exit 1
fi

ARTIFACT="$1"
UDID="$2"
WORKDIR=""

cleanup() {
  if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
    rm -rf "$WORKDIR"
  fi
}
trap cleanup EXIT

install_app() {
  xcrun simctl install "$UDID" "$1" >/dev/null
}

if [[ -d "$ARTIFACT" ]]; then
  install_app "$ARTIFACT"
  exit 0
fi

if [[ "$ARTIFACT" == *.zip ]]; then
  WORKDIR="$(mktemp -d)"
  unzip -q "$ARTIFACT" -d "$WORKDIR"
  APP_PATH="$(find "$WORKDIR" -maxdepth 2 -name '*.app' -print -quit)"
  if [[ -z "$APP_PATH" ]]; then
    echo "no .app bundle found in $ARTIFACT" >&2
    exit 1
  fi
  install_app "$APP_PATH"
  exit 0
fi

echo "unsupported artifact: $ARTIFACT" >&2
exit 1
