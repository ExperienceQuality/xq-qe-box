#!/usr/bin/env bash
set -euo pipefail

VERSION=""
ARTIFACT=""
OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --artifact)
      ARTIFACT="$2"
      shift 2
      ;;
    --out)
      OUT="$2"
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" || -z "$ARTIFACT" || -z "$OUT" ]]; then
  echo "usage: fetch-release.sh --version VERSION --artifact NAME --out PATH" >&2
  exit 1
fi

declare -A CHECKSUMS=(
  ["devicekit-ios-Sim-arm64.zip"]="8040f4918892f63d79713b5824184ac5f296c5ec9b23266c25af34777550f28c"
  ["devicekit-ios-Sim-x86_64.zip"]="78a8f2d208a22523efbaa5cb2a735557e807f877bb8ec1a1c31c886f2e425684"
  ["devicekit-ios-runner.ipa"]="f5fe88d4169c39001ed012101651c5ac00e8ab54aefb72c74455e7037c2e8205"
)

EXPECTED="${CHECKSUMS[$ARTIFACT]:-}"
if [[ -z "$EXPECTED" ]]; then
  echo "no pinned checksum for $ARTIFACT" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
URL="https://github.com/mobile-next/devicekit-ios/releases/download/${VERSION}/${ARTIFACT}"
curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "$OUT" "$URL"

ACTUAL="$(shasum -a 256 "$OUT" | awk '{print $1}')"
if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "checksum mismatch for $ARTIFACT: expected $EXPECTED got $ACTUAL" >&2
  rm -f "$OUT"
  exit 1
fi

realpath "$OUT"
