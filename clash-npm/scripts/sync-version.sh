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
