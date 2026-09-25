import { spawnSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const args = process.argv.slice(2);
const linked = args.includes("--linked");
const local = args.includes("--local") || !linked;
const outputFlag = args.indexOf("--output");
const outputPath = resolve(
  outputFlag >= 0 ? args[outputFlag + 1] : "src/types/database.ts",
);

if (linked && local) {
  throw new Error("Choose exactly one type source: --local or --linked.");
}

if (linked && outputFlag < 0) {
  throw new Error("Remote type generation requires an explicit --output path.");
}

if (outputFlag >= 0 && !args[outputFlag + 1]) {
  throw new Error("--output requires a path.");
}

const cliPath = resolve("node_modules/supabase/dist/supabase.js");
const result = spawnSync(
  process.execPath,
  [
    cliPath,
    "gen",
    "types",
    linked ? "--linked" : "--local",
    "--lang",
    "typescript",
    "--schema",
    "public",
  ],
  {
    cwd: process.cwd(),
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  },
);

if (result.stderr) {
  process.stderr.write(result.stderr);
}

if (result.error) {
  throw result.error;
}

if (result.status !== 0) {
  process.exit(result.status ?? 1);
}

const hostedPostgrestMetadata = /^  \/\/ Allows to automatically instantiate createClient with right options\r?\n  \/\/ instead of createClient<Database, \{ PostgrestVersion: 'XX' \}>\(URL, KEY\)\r?\n  __InternalSupabase: \{\r?\n    PostgrestVersion: "[^"]+"\r?\n  \}\r?\n/m;

const normalized = result.stdout
  .replace(hostedPostgrestMetadata, "")
  .replaceAll("\r\n", "\n")
  .trimEnd()
  .concat("\n");

if (!normalized.includes("export type Database =")) {
  throw new Error("Supabase type generation did not return a Database type.");
}

mkdirSync(dirname(outputPath), { recursive: true });
writeFileSync(outputPath, normalized, "utf8");
