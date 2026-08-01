#!/usr/bin/env bash
# Install pinned upstream agent-device for XQ agent-native QE.
set -euo pipefail

AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-0.20.3}"

log() { printf '+ %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd node
need_cmd npm

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  die "Node.js >= 22.12 required (found $(node -v))"
fi

log "Installing agent-device@${AGENT_DEVICE_VERSION} globally"
npm install -g "agent-device@${AGENT_DEVICE_VERSION}"

log "Versions"
echo "  node         $(node -v)"
echo "  agent-device $(agent-device --version 2>/dev/null || echo 'NOT ON PATH')"

if ! command -v agent-device >/dev/null 2>&1; then
  die "agent-device not on PATH after install — check npm global bin in your shell PATH"
fi

log "agent-device doctor (best-effort)"
agent-device doctor || true

cat <<'EOF'

Install complete.

Skills (from this repo):
  npx skills add ExperienceQuality/xq-qe-box --list
  npx skills add ExperienceQuality/xq-qe-box --skill xq-device

Sanity:
  agent-device --version
  agent-device help workflow

Pin override:
  AGENT_DEVICE_VERSION=0.20.3 bash scripts/install-cli.sh
EOF
