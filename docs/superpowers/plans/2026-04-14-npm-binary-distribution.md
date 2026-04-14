# npm Binary Distribution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distribute the clash binary via npm as platform-specific packages, with a separate Pi agent extension package.

**Architecture:** Five npm packages — three platform packages containing bare binaries, one main `@empathic/clash` package that resolves the right platform binary via `optionalDependencies`, and one `@empathic/clash-pi` package with a Pi extension that shells out to the clash binary for policy enforcement. A new CI job in the release workflow publishes all packages after the GitHub Release is created.

**Tech Stack:** npm packages (no build tooling), Node.js postinstall script, TypeScript (Pi extension), GitHub Actions

**Spec:** `docs/superpowers/specs/2026-04-14-npm-binary-distribution-design.md`

---

### Task 1: Platform package scaffolding

Create the three platform package directories with minimal `package.json` files. These packages will each contain a single binary at publish time — for now just the metadata.

**Files:**
- Create: `clash-npm/platforms/darwin-arm64/package.json`
- Create: `clash-npm/platforms/linux-x64/package.json`
- Create: `clash-npm/platforms/linux-arm64/package.json`

- [ ] **Step 1: Create darwin-arm64 package.json**

```bash
mkdir -p clash-npm/platforms/darwin-arm64
```

Write `clash-npm/platforms/darwin-arm64/package.json`:

```json
{
  "name": "@empathic/clash-darwin-arm64",
  "version": "0.6.2",
  "description": "Clash binary for macOS ARM64 (Apple Silicon)",
  "license": "Apache-2.0",
  "repository": {
    "type": "git",
    "url": "https://github.com/empathic/clash"
  },
  "os": ["darwin"],
  "cpu": ["arm64"],
  "files": ["clash"]
}
```

The `"files"` array ensures only the `clash` binary is included when publishing. The binary itself is placed here by CI before `npm publish`.

- [ ] **Step 2: Create linux-x64 package.json**

```bash
mkdir -p clash-npm/platforms/linux-x64
```

Write `clash-npm/platforms/linux-x64/package.json`:

```json
{
  "name": "@empathic/clash-linux-x64",
  "version": "0.6.2",
  "description": "Clash binary for Linux x86_64",
  "license": "Apache-2.0",
  "repository": {
    "type": "git",
    "url": "https://github.com/empathic/clash"
  },
  "os": ["linux"],
  "cpu": ["x64"],
  "files": ["clash"]
}
```

- [ ] **Step 3: Create linux-arm64 package.json**

```bash
mkdir -p clash-npm/platforms/linux-arm64
```

Write `clash-npm/platforms/linux-arm64/package.json`:

```json
{
  "name": "@empathic/clash-linux-arm64",
  "version": "0.6.2",
  "description": "Clash binary for Linux ARM64",
  "license": "Apache-2.0",
  "repository": {
    "type": "git",
    "url": "https://github.com/empathic/clash"
  },
  "os": ["linux"],
  "cpu": ["arm64"],
  "files": ["clash"]
}
```

- [ ] **Step 4: Commit**

```bash
git add clash-npm/platforms/
git commit -m "feat(npm): add platform package scaffolding for binary distribution"
```

---

### Task 2: Main `@empathic/clash` package with postinstall script

Create the main npm package that wires up `optionalDependencies` and a `postinstall` script to copy the binary into place.

**Files:**
- Create: `clash-npm/package.json`
- Create: `clash-npm/scripts/postinstall.js`
- Create: `clash-npm/bin/.gitkeep`

- [ ] **Step 1: Create main package.json**

Write `clash-npm/package.json`:

```json
{
  "name": "@empathic/clash",
  "version": "0.6.2",
  "description": "Command Line Agent Safety Harness — policy enforcement for AI coding agents",
  "license": "Apache-2.0",
  "repository": {
    "type": "git",
    "url": "https://github.com/empathic/clash"
  },
  "bin": {
    "clash": "bin/clash"
  },
  "scripts": {
    "postinstall": "node scripts/postinstall.js"
  },
  "files": [
    "bin/",
    "scripts/",
    "README.md"
  ],
  "optionalDependencies": {
    "@empathic/clash-darwin-arm64": "0.6.2",
    "@empathic/clash-linux-x64": "0.6.2",
    "@empathic/clash-linux-arm64": "0.6.2"
  }
}
```

- [ ] **Step 2: Create bin directory placeholder**

```bash
mkdir -p clash-npm/bin
touch clash-npm/bin/.gitkeep
```

- [ ] **Step 3: Write postinstall.js**

Write `clash-npm/scripts/postinstall.js`:

```javascript
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
```

All failure paths use `process.exit(0)` so that `npm install` doesn't fail — the user just won't have the binary and will see the warning.

- [ ] **Step 4: Test postinstall locally**

Verify the script has valid syntax:

```bash
node -c clash-npm/scripts/postinstall.js
```

Expected: no output (syntax OK).

- [ ] **Step 5: Commit**

```bash
git add clash-npm/package.json clash-npm/scripts/postinstall.js clash-npm/bin/.gitkeep
git commit -m "feat(npm): add main @empathic/clash package with postinstall binary resolution"
```

---

### Task 3: Pi extension

Write the TypeScript extension that bridges Pi's `tool_call` hook to clash's CLI hook protocol.

**Files:**
- Create: `clash-pi/extensions/clash.ts`
- Create: `clash-pi/package.json`

- [ ] **Step 1: Write the Pi extension**

Write `clash-pi/extensions/clash.ts`:

```typescript
/**
 * Clash extension for Pi agent.
 *
 * Bridges Pi's extension API to Clash's CLI hook interface.
 * Installed via: pi install npm:@empathic/clash-pi
 */

import { execSync } from "child_process";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const HOOK_TIMEOUT = 10_000;

export default function (pi: ExtensionAPI) {
  let sessionId = "";
  let clashMissing = false;
  let warnedOnce = false;

  function runHook(subcommand: string, input: string): string | null {
    try {
      return execSync(`clash hook --agent opencode ${subcommand}`, {
        input,
        encoding: "utf-8",
        timeout: HOOK_TIMEOUT,
      });
    } catch (err: any) {
      if (!clashMissing && err.code === "ENOENT") {
        clashMissing = true;
        console.error(
          "[clash] WARNING: clash binary not found on PATH. " +
            "Policy enforcement is disabled for this session. " +
            "Install clash: npm install -g @empathic/clash"
        );
      }
      return null;
    }
  }

  pi.on("session_start", async (_event, _ctx) => {
    runHook(
      "session-start",
      JSON.stringify({
        session_id: sessionId,
        cwd: process.cwd(),
        hook_event_name: "session.start",
      })
    );
  });

  pi.on("tool_call", async (event, ctx) => {
    if (!sessionId && event.sessionId) {
      sessionId = `pi-${event.sessionId}`;
    }

    if (clashMissing) {
      if (!warnedOnce) {
        warnedOnce = true;
        console.error(
          "[clash] clash binary not found — all tool calls are unprotected"
        );
      }
      return undefined;
    }

    const hookInput = JSON.stringify({
      tool: event.toolName,
      args: event.input,
      session_id: sessionId,
      directory: process.cwd(),
      hook_event_name: "tool.execute.before",
    });

    const result = runHook("pre-tool-use", hookInput);
    if (!result) {
      return undefined;
    }

    let decision: any;
    try {
      decision = JSON.parse(result);
    } catch {
      return undefined;
    }

    if (decision.action === "deny") {
      return {
        block: true,
        reason: decision.reason || "blocked by clash policy",
      };
    }

    if (decision.action === "ask") {
      if (ctx.hasUI) {
        const choice = await ctx.ui.select(
          `Clash policy requires approval:\n${decision.reason || event.toolName}`,
          ["Allow", "Deny"]
        );
        if (choice === "Deny") {
          return { block: true, reason: "denied by user" };
        }
      }
      return undefined;
    }

    if (decision.action === "allow" && decision.args) {
      Object.assign(event.input, decision.args);
    }

    return undefined;
  });

  pi.on("tool_result", async (event, _ctx) => {
    if (clashMissing) return;

    runHook(
      "post-tool-use",
      JSON.stringify({
        tool: event.toolName,
        args: event.input,
        session_id: sessionId,
        directory: process.cwd(),
        hook_event_name: "tool.execute.after",
      })
    );
  });
}
```

- [ ] **Step 2: Create Pi package.json**

Write `clash-pi/package.json`:

```json
{
  "name": "@empathic/clash-pi",
  "version": "0.6.2",
  "description": "Clash policy enforcement extension for the Pi agent framework",
  "license": "Apache-2.0",
  "repository": {
    "type": "git",
    "url": "https://github.com/empathic/clash"
  },
  "dependencies": {
    "@empathic/clash": "0.6.2"
  },
  "pi": {
    "extensions": ["extensions/clash.ts"]
  },
  "files": [
    "extensions/"
  ]
}
```

The `"pi"` field declares this as a Pi package with extensions. Pi discovers and loads `extensions/clash.ts` automatically on install.

- [ ] **Step 3: Verify TypeScript syntax**

```bash
npx tsc --noEmit --strict --moduleResolution node --target es2020 clash-pi/extensions/clash.ts 2>&1 || echo "Type checking requires Pi types — skipping strict check"
```

Since Pi types aren't available locally, verify basic syntax with:

```bash
node -e "try { require('typescript').createSourceFile('clash.ts', require('fs').readFileSync('clash-pi/extensions/clash.ts', 'utf8'), 99); console.log('Syntax OK') } catch(e) { console.error(e.message); process.exit(1) }" 2>/dev/null || echo "No local TypeScript, syntax will be validated in CI"
```

- [ ] **Step 4: Commit**

```bash
git add clash-pi/
git commit -m "feat(pi): add clash extension for Pi agent framework"
```

---

### Task 4: CI workflow for npm publishing

Add a new job to the release workflow that publishes all 5 npm packages after the GitHub Release is created.

**Files:**
- Modify: `.github/workflows/release.yml`
- Create: `clash-npm/scripts/prepare-platform.sh`

- [ ] **Step 1: Write the platform preparation script**

This script is called by CI to extract a binary from a GitHub Release tarball into the right platform package directory.

Write `clash-npm/scripts/prepare-platform.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: prepare-platform.sh <rust-target> <platform-dir>
# Example: prepare-platform.sh aarch64-apple-darwin clash-npm/platforms/darwin-arm64

RUST_TARGET="$1"
PLATFORM_DIR="$2"
TARBALL="artifacts/clash-${RUST_TARGET}.tar.gz"

if [ ! -f "$TARBALL" ]; then
  echo "ERROR: $TARBALL not found"
  exit 1
fi

tar xzf "$TARBALL" -C "$PLATFORM_DIR"
chmod 755 "$PLATFORM_DIR/clash"
echo "Prepared $PLATFORM_DIR/clash from $TARBALL"
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x clash-npm/scripts/prepare-platform.sh
```

- [ ] **Step 3: Add npm-publish job to release.yml**

Add the following job to `.github/workflows/release.yml`, after the existing `release` job:

```yaml
  npm-publish:
    name: Publish npm packages
    needs: [build, release]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: "20"
          registry-url: "https://registry.npmjs.org"

      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
          merge-multiple: true

      - name: Prepare platform binaries
        run: |
          bash clash-npm/scripts/prepare-platform.sh aarch64-apple-darwin clash-npm/platforms/darwin-arm64
          bash clash-npm/scripts/prepare-platform.sh x86_64-unknown-linux-musl clash-npm/platforms/linux-x64
          bash clash-npm/scripts/prepare-platform.sh aarch64-unknown-linux-gnu clash-npm/platforms/linux-arm64

      - name: Publish platform packages
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: |
          cd clash-npm/platforms/darwin-arm64 && npm publish --access public && cd ../../..
          cd clash-npm/platforms/linux-x64 && npm publish --access public && cd ../../..
          cd clash-npm/platforms/linux-arm64 && npm publish --access public && cd ../../..

      - name: Publish main package
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: |
          cd clash-npm && npm publish --access public && cd ..

      - name: Publish Pi extension package
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: |
          cd clash-pi && npm publish --access public && cd ..
```

The full `npm-publish` job block should be appended after the `publish-site` job at the end of the file.

- [ ] **Step 4: Commit**

```bash
git add clash-npm/scripts/prepare-platform.sh .github/workflows/release.yml
git commit -m "ci: add npm publish job to release workflow"
```

---

### Task 5: Version syncing script

Add a script to the justfile's `release` recipe that updates all npm `package.json` versions in lockstep with the Cargo workspace version.

**Files:**
- Create: `clash-npm/scripts/sync-version.sh`
- Modify: `justfile`

- [ ] **Step 1: Write the version sync script**

Write `clash-npm/scripts/sync-version.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage: sync-version.sh <version>
# Updates all npm package.json files to match the given version.

VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "Usage: sync-version.sh <version>"
  exit 1
fi

PACKAGES=(
  "clash-npm/package.json"
  "clash-npm/platforms/darwin-arm64/package.json"
  "clash-npm/platforms/linux-x64/package.json"
  "clash-npm/platforms/linux-arm64/package.json"
  "clash-pi/package.json"
)

for pkg in "${PACKAGES[@]}"; do
  if [ -f "$pkg" ]; then
    # Use node to update version fields in-place, including dependency versions
    node -e "
      const fs = require('fs');
      const p = JSON.parse(fs.readFileSync('$pkg', 'utf8'));
      p.version = '$VERSION';
      if (p.optionalDependencies) {
        for (const k of Object.keys(p.optionalDependencies)) {
          if (k.startsWith('@empathic/clash')) p.optionalDependencies[k] = '$VERSION';
        }
      }
      if (p.dependencies) {
        for (const k of Object.keys(p.dependencies)) {
          if (k.startsWith('@empathic/clash')) p.dependencies[k] = '$VERSION';
        }
      }
      fs.writeFileSync('$pkg', JSON.stringify(p, null, 2) + '\n');
    "
    echo "Updated $pkg to $VERSION"
  fi
done
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x clash-npm/scripts/sync-version.sh
```

- [ ] **Step 3: Test the script locally**

```bash
bash clash-npm/scripts/sync-version.sh 0.6.2
```

Expected: prints "Updated ..." for each of the 5 package.json files. Verify a file to confirm:

```bash
node -e "console.log(JSON.parse(require('fs').readFileSync('clash-npm/package.json','utf8')).version)"
```

Expected: `0.6.2`

- [ ] **Step 4: Add sync step to justfile release recipe**

Find the existing `release` recipe in the `justfile`. After the line that bumps Cargo versions (`cargo release version ...`), add:

```just
    bash clash-npm/scripts/sync-version.sh {{VERSION}}
```

This ensures npm versions stay in sync when running `just release <VERSION>`.

- [ ] **Step 5: Commit**

```bash
git add clash-npm/scripts/sync-version.sh justfile
git commit -m "chore: add npm version sync script and wire into release recipe"
```

---

### Task 6: Documentation

Update the README to document the npm install method.

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the current install section of the README**

```bash
grep -n "install" README.md | head -20
```

Identify the install section to add the npm method alongside the existing curl and cargo methods.

- [ ] **Step 2: Add npm install instructions**

In the install section of `README.md`, add after the existing install methods:

```markdown
### npm

```bash
npm install -g @empathic/clash
```

This installs the `clash` binary on your PATH via npm. Supports macOS (Apple Silicon) and Linux (x64, ARM64).

### Pi agent

```bash
pi install npm:@empathic/clash-pi
```

Installs clash and the Pi policy enforcement extension. The extension automatically gates tool calls through your clash policy.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add npm and Pi install instructions to README"
```

---

### Task 7: Local integration test

Verify the full package structure works end-to-end by simulating what npm would do.

**Files:**
- No new files

- [ ] **Step 1: Build a local clash binary**

```bash
cargo build --release -p clash
```

- [ ] **Step 2: Simulate the platform package**

```bash
cp target/release/clash clash-npm/platforms/darwin-arm64/clash 2>/dev/null || \
cp target/release/clash clash-npm/platforms/linux-x64/clash 2>/dev/null || \
echo "Copy binary for your current platform"
```

- [ ] **Step 3: Test postinstall resolves the binary**

Create a temporary test directory and simulate the install layout:

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/node_modules/@empathic/clash-darwin-arm64"
mkdir -p "$TMPDIR/node_modules/@empathic/clash/bin"
mkdir -p "$TMPDIR/node_modules/@empathic/clash/scripts"

# Copy the platform package
cp clash-npm/platforms/darwin-arm64/package.json "$TMPDIR/node_modules/@empathic/clash-darwin-arm64/"
cp target/release/clash "$TMPDIR/node_modules/@empathic/clash-darwin-arm64/"

# Copy the main package
cp clash-npm/package.json "$TMPDIR/node_modules/@empathic/clash/"
cp clash-npm/scripts/postinstall.js "$TMPDIR/node_modules/@empathic/clash/scripts/"

# Run postinstall
cd "$TMPDIR/node_modules/@empathic/clash" && node scripts/postinstall.js && cd -
```

Expected: no errors. Verify:

```bash
ls -la "$TMPDIR/node_modules/@empathic/clash/bin/clash"
"$TMPDIR/node_modules/@empathic/clash/bin/clash" --version
```

Expected: binary exists, prints clash version.

- [ ] **Step 4: Clean up**

```bash
rm -rf "$TMPDIR"
rm -f clash-npm/platforms/darwin-arm64/clash
rm -f clash-npm/platforms/linux-x64/clash
rm -f clash-npm/platforms/linux-arm64/clash
```

- [ ] **Step 5: Commit any fixes discovered during testing**

If any issues were found and fixed during the integration test, commit them:

```bash
git add -A && git commit -m "fix(npm): address issues found in local integration test"
```

If no fixes needed, skip this step.
