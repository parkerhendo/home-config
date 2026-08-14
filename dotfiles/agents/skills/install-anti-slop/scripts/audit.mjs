#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const skillRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const source = resolve(skillRoot, "assets/anti-slop");
const cacheBase = process.env.XDG_CACHE_HOME ?? resolve(homedir(), ".cache");
const runtime = resolve(cacheBase, "pi/anti-slop-audit");
const versionFile = resolve(runtime, "versions.json");
const npm = process.platform === "win32" ? "npm.cmd" : "npm";
const oxlint = resolve(
  runtime,
  "node_modules/.bin",
  process.platform === "win32" ? "oxlint.cmd" : "oxlint",
);
const arguments_ = process.argv.slice(2);

if (arguments_.includes("--help")) {
  console.log("Usage: audit.mjs [--refresh] [path ...]");
  console.log("Runs anti-slop without changing the target repository.");
  process.exit(0);
}

const unsupportedOption = arguments_.find(
  (argument) => argument.startsWith("-") && argument !== "--refresh",
);
if (unsupportedOption !== undefined) {
  console.error(`Unsupported option: ${unsupportedOption}`);
  process.exit(2);
}

const refresh = arguments_.includes("--refresh");
const targets = arguments_.filter((argument) => argument !== "--refresh");
if (targets.length === 0) targets.push(".");

function run(command, args, options = {}) {
  const result = spawnSync(command, args, options);
  if (result.error !== undefined) {
    console.error(result.error.message);
    process.exit(1);
  }
  return result;
}

function currentVersion(packageName) {
  const result = run(npm, ["view", packageName, "version"], {
    cwd: runtime,
    encoding: "utf8",
  });
  if (result.status !== 0) {
    process.stderr.write(result.stderr);
    process.exit(result.status ?? 1);
  }
  return result.stdout.trim();
}

function cachedVersions() {
  if (!existsSync(versionFile) || !existsSync(oxlint)) return null;
  try {
    const versions = JSON.parse(readFileSync(versionFile, "utf8"));
    if (typeof versions.oxlint !== "string" || typeof versions.plugins !== "string") return null;
    if (!existsSync(resolve(runtime, "node_modules/@oxlint/plugins/package.json"))) return null;
    return versions;
  } catch {
    return null;
  }
}

function installRuntime() {
  mkdirSync(runtime, { recursive: true });
  const versions = {
    oxlint: currentVersion("oxlint"),
    plugins: currentVersion("@oxlint/plugins"),
  };
  if (versions.oxlint !== versions.plugins) {
    console.error(
      `Oxlint package versions do not match: oxlint=${versions.oxlint}, @oxlint/plugins=${versions.plugins}`,
    );
    process.exit(1);
  }

  writeFileSync(
    resolve(runtime, "package.json"),
    `${JSON.stringify(
      {
        private: true,
        type: "module",
        dependencies: {
          "@oxlint/plugins": versions.plugins,
          oxlint: versions.oxlint,
        },
      },
      null,
      2,
    )}\n`,
  );

  console.log(`Preparing cached anti-slop runtime with Oxlint ${versions.oxlint}...`);
  const result = run(
    npm,
    [
      "install",
      "--prefix",
      runtime,
      "--ignore-scripts",
      "--no-audit",
      "--no-fund",
      "--no-package-lock",
      "--save-exact",
    ],
    { cwd: runtime, stdio: "inherit" },
  );
  if (result.status !== 0) process.exit(result.status ?? 1);
  writeFileSync(versionFile, `${JSON.stringify(versions, null, 2)}\n`);
  return versions;
}

const cached = refresh ? null : cachedVersions();
const versions = cached ?? installRuntime();
const pluginTarget = resolve(runtime, "anti-slop");
rmSync(pluginTarget, { recursive: true, force: true });
cpSync(source, pluginTarget, { recursive: true });

const rules = Object.fromEntries(
  [
    "no-chained-type-assertions",
    "no-conditional-empty-object-spread",
    "no-known-value-widening",
    "no-module-mocking",
    "no-object-parameters",
    "no-reflect-apply",
    "no-reflect-get",
    "no-runtime-typeof",
    "no-shape-in-symbol-names",
    "no-unknown-parameters",
    "no-unknown-returns",
    "no-unknown-type-aliases",
    "no-unsafe-dictionary-type",
    "no-widen-then-assert",
    "require-safety-comment-for-type-assertion",
  ].map((rule) => [`anti-slop/${rule}`, "error"]),
);
const config = resolve(runtime, "oxlint.config.json");
writeFileSync(
  config,
  `${JSON.stringify(
    {
      jsPlugins: [{ name: "anti-slop", specifier: "./anti-slop/index.ts" }],
      rules,
    },
    null,
    2,
  )}\n`,
);

console.log(
  `Running anti-slop with Oxlint ${versions.oxlint}; target repository files will not be changed.`,
);
const result = run(oxlint, ["--config", config, "--disable-nested-config", ...targets], {
  cwd: process.cwd(),
  stdio: "inherit",
});
process.exit(result.status ?? 1);
