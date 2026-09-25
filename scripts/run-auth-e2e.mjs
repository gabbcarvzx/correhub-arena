import { spawn, spawnSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";

import { buildNextEnvironment, validateLocalSupabaseStatus } from "./auth-e2e-env.mjs";

const npmCli = process.env.npm_execpath;
if (!npmCli) {
  throw new Error("Run Auth E2E through npm run test:auth");
}

function runNpm(args) {
  return spawnSync(process.execPath, [npmCli, ...args], {
    cwd: process.cwd(),
    encoding: "utf8",
    env: process.env,
    windowsHide: true,
  });
}

function parseEnvironment(output) {
  return Object.fromEntries(
    output
      .split(/\r?\n/)
      .map((line) => /^([A-Z0-9_]+)=(.*)$/.exec(line.trim()))
      .filter(Boolean)
      .map((match) => {
        const raw = match[2];
        let value = raw;
        if (raw.startsWith('"') && raw.endsWith('"')) {
          try {
            value = JSON.parse(raw);
          } catch {
            value = raw.slice(1, -1);
          }
        }
        return [match[1], value];
      }),
  );
}

function localStatus() {
  let result = runNpm(["exec", "--no", "--", "supabase", "status", "-o", "env"]);
  if (result.status !== 0) {
    const start = runNpm(["run", "db:start"]);
    if (start.status !== 0) {
      throw new Error("Supabase local could not start");
    }
    result = runNpm(["exec", "--no", "--", "supabase", "status", "-o", "env"]);
  }
  if (result.status !== 0) {
    throw new Error("Supabase local status is unavailable");
  }
  return parseEnvironment(result.stdout);
}

async function waitForNext(processHandle) {
  const deadline = Date.now() + 120_000;
  while (Date.now() < deadline) {
    if (processHandle.exitCode !== null) {
      throw new Error("Next development server exited before becoming ready");
    }
    try {
      const response = await fetch("http://localhost:3000/login", { redirect: "manual" });
      if (response.status > 0) {
        return;
      }
    } catch {
      // Server is still booting.
    }
    await delay(500);
  }
  throw new Error("Next development server did not become ready");
}

function stopProcessTree(processHandle) {
  if (!processHandle || processHandle.exitCode !== null) {
    return;
  }
  if (process.platform === "win32") {
    spawnSync("taskkill", ["/pid", String(processHandle.pid), "/T", "/F"], {
      stdio: "ignore",
      windowsHide: true,
    });
  } else {
    processHandle.kill("SIGTERM");
  }
}

const status = localStatus();
const local = validateLocalSupabaseStatus(status);
const nextEnvironment = buildNextEnvironment(status);
const next = spawn(
  process.execPath,
  ["node_modules/next/dist/bin/next", "dev", "--hostname", "127.0.0.1", "--port", "3000"],
  {
    cwd: process.cwd(),
    env: nextEnvironment,
    stdio: ["ignore", "pipe", "pipe"],
    windowsHide: true,
  },
);

let serverOutput = "";
for (const stream of [next.stdout, next.stderr]) {
  stream.on("data", (chunk) => {
    serverOutput = `${serverOutput}${chunk}`.slice(-8_000);
  });
}

let exitCode = 1;
try {
  await waitForNext(next);
  const playwrightEnvironment = {
    ...nextEnvironment,
    LOCAL_SUPABASE_SERVICE_ROLE_KEY: local.serviceRoleKey,
  };
  const playwright = spawnSync(
    process.execPath,
    ["node_modules/@playwright/test/cli.js", "test"],
    {
      cwd: process.cwd(),
      env: playwrightEnvironment,
      stdio: "inherit",
      windowsHide: true,
    },
  );
  exitCode = playwright.status ?? 1;
} catch (error) {
  const safeMessage = error instanceof Error ? error.message : "Unknown Auth E2E failure";
  console.error(safeMessage);
  if (serverOutput) {
    console.error(serverOutput.replace(/(token|secret|password|key)=\S+/gi, "$1=[redacted]"));
  }
} finally {
  stopProcessTree(next);
}

process.exitCode = exitCode;
