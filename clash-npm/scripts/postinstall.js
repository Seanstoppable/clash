"use strict";

const { copyFileSync, chmodSync } = require("fs");
const { join } = require("path");

const PLATFORMS = {
  "darwin-arm64": "@empathic/clash-darwin-arm64",
  "linux-x64": "@empathic/clash-linux-x64",
  "linux-arm64": "@empathic/clash-linux-arm64",
};

const key = `${process.platform}-${process.arch}`;
const pkg = PLATFORMS[key];

if (!pkg) {
  console.warn(
    `[clash] Unsupported platform: ${key}. ` +
      `Install clash manually: https://github.com/empathic/clash#install`
  );
  process.exit(0);
}

let src;
try {
  src = join(require.resolve(`${pkg}/package.json`), "..", "clash");
} catch {
  console.warn(
    `[clash] Platform package ${pkg} not installed. ` +
      `This can happen if your package manager skips optional dependencies. ` +
      `Install clash manually: https://github.com/empathic/clash#install`
  );
  process.exit(0);
}

const dest = join(__dirname, "..", "bin", "clash");

try {
  copyFileSync(src, dest);
  chmodSync(dest, 0o755);
} catch (err) {
  console.warn(`[clash] Failed to install binary: ${err.message}`);
  process.exit(0);
}
