#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "swift: skipped (non-macOS host)"
  exit 0
fi

if [[ ! -f "$ROOT/swift/Package.swift" ]]; then
  echo "swift: skipped (WP1b not implemented)"
  exit 0
fi

cd "$ROOT/swift"
swift test
