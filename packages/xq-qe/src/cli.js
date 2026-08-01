import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const { version: XQ_QE_VERSION } = require("../package.json");

/** Minimum agent-device version required by the xq-qe skill / install pin. */
export const AGENT_DEVICE_MIN = "0.20.0";

const HELP = `xq-qe — XQ wrapper CLI for agent-native QE

Usage:
  xq-qe --version
  xq-qe doctor
  xq-qe help

Pairs with upstream agent-device (installed by scripts/install-cli.sh).
For device automation commands, read installed help:

  agent-device help workflow
  agent-device help manual-qa
  agent-device help validate
  agent-device help dogfood
`;

function parseSemver(v) {
  const m = String(v)
    .trim()
    .replace(/^v/, "")
    .match(/^(\d+)\.(\d+)\.(\d+)/);
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

function gte(a, b) {
  for (let i = 0; i < 3; i++) {
    if (a[i] > b[i]) return true;
    if (a[i] < b[i]) return false;
  }
  return true;
}

function resolveAgentDevice() {
  const which = spawnSync("which", ["agent-device"], { encoding: "utf8" });
  if (which.status === 0) {
    const path = which.stdout.trim().split("\n")[0];
    if (path) return path;
  }
  return "agent-device";
}

function agentDeviceVersion(bin) {
  const r = spawnSync(bin, ["--version"], { encoding: "utf8" });
  if (r.status !== 0) {
    return { ok: false, error: (r.stderr || r.stdout || "agent-device --version failed").trim() };
  }
  const text = `${r.stdout || ""}${r.stderr || ""}`.trim();
  const sem = parseSemver(text);
  if (!sem) {
    return { ok: false, error: `could not parse agent-device version from: ${text}` };
  }
  return { ok: true, text, sem, bin };
}

export async function main(argv) {
  const cmd = argv[0];

  if (!cmd || cmd === "help" || cmd === "--help" || cmd === "-h") {
    process.stdout.write(HELP);
    return;
  }

  if (cmd === "--version" || cmd === "-v" || cmd === "version") {
    process.stdout.write(`${XQ_QE_VERSION}\n`);
    return;
  }

  if (cmd === "doctor") {
    runDoctor();
    return;
  }

  console.error(`Unknown command: ${cmd}\n`);
  process.stdout.write(HELP);
  process.exitCode = 1;
}

function runDoctor() {
  const nodeMajor = Number(process.versions.node.split(".")[0]);
  const checks = [];

  checks.push({
    name: "node",
    ok: nodeMajor >= 22,
    detail: `node ${process.versions.node} (need >= 22.12)`,
  });

  checks.push({
    name: "xq-qe",
    ok: true,
    detail: `xq-qe ${XQ_QE_VERSION} @ ${join(dirname(fileURLToPath(import.meta.url)), "..")}`,
  });

  const bin = resolveAgentDevice();
  const ad = agentDeviceVersion(bin);
  const min = parseSemver(AGENT_DEVICE_MIN);

  if (!ad.ok) {
    checks.push({
      name: "agent-device",
      ok: false,
      detail: ad.error || "not found on PATH — run scripts/install-cli.sh",
    });
  } else {
    const ok = gte(ad.sem, min);
    checks.push({
      name: "agent-device",
      ok,
      detail: ok
        ? `${ad.bin} → ${ad.text} (min ${AGENT_DEVICE_MIN})`
        : `${ad.text} is below min ${AGENT_DEVICE_MIN} — re-run scripts/install-cli.sh`,
    });
  }

  let failed = false;
  for (const c of checks) {
    const mark = c.ok ? "ok" : "FAIL";
    if (!c.ok) failed = true;
    console.log(`[${mark}] ${c.name}: ${c.detail}`);
  }

  if (failed) {
    console.log("\nNext: bash scripts/install-cli.sh");
    process.exitCode = 1;
    return;
  }

  console.log("\nReady. For agents: agent-device help workflow");
}
