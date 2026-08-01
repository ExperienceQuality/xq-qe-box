#!/usr/bin/env bash
# Install upstream agent-device (pinned) and the XQ wrapper CLI (xq-qe) from this repo.
set -euo pipefail

AGENT_DEVICE_VERSION="${AGENT_DEVICE_VERSION:-0.20.3}"
REPO_URL="${XQ_QE_BOX_REPO:-https://github.com/ExperienceQuality/xq-qe-box.git}"
REPO_REF="${XQ_QE_BOX_REF:-main}"

log() { printf '+ %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd node
need_cmd npm
need_cmd git

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" -lt 22 ]]; then
  die "Node.js >= 22.12 required (found $(node -v))"
fi

log "Installing agent-device@${AGENT_DEVICE_VERSION} globally"
npm install -g "agent-device@${AGENT_DEVICE_VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/packages/xq-qe/package.json" ]]; then
  log "Installing xq-qe from local checkout: ${REPO_ROOT}/packages/xq-qe"
  npm install -g "${REPO_ROOT}/packages/xq-qe"
else
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  log "Cloning ${REPO_URL} (${REPO_REF}) into temp dir"
  git clone --depth 1 --branch "${REPO_REF}" "${REPO_URL}" "${TMP}/xq-qe-box"
  log "Installing xq-qe from clone"
  npm install -g "${TMP}/xq-qe-box/packages/xq-qe"
fi

log "Versions"
echo "  node         $(node -v)"
echo "  agent-device $(agent-device --version 2>/dev/null || echo 'NOT ON PATH')"
echo "  xq-qe        $(xq-qe --version 2>/dev/null || echo 'NOT ON PATH')"

log "Running xq-qe doctor"
xq-qe doctor

cat <<'EOF'

Install complete.

Agent / skills:
  npx skills add ExperienceQuality/xq-qe-box --skill xq-qe

Human sanity:
  xq-qe doctor
  agent-device help workflow

Pin overrides:
  AGENT_DEVICE_VERSION=0.20.3 bash scripts/install-cli.sh
EOF
