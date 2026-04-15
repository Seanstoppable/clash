#!/usr/bin/env bash
set -euo pipefail

# Publish all npm packages for the current version.
#
# 1. Reads the version from clash-npm/package.json
# 2. Downloads release binaries from GitHub and stages them into platform packages
# 3. Publishes all 5 packages to npm, skipping any already-published versions
#
# Requires: curl, tar, node, npm (logged in with publish rights to @empathic)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

VERSION=$(node -p "require('./clash-npm/package.json').version")
echo "Publishing clash npm packages at version $VERSION"

# Stage platform binaries
bash clash-npm/scripts/prepare-platform.sh aarch64-apple-darwin clash-npm/platforms/darwin-arm64 "$VERSION"
bash clash-npm/scripts/prepare-platform.sh x86_64-unknown-linux-musl clash-npm/platforms/linux-x64 "$VERSION"
bash clash-npm/scripts/prepare-platform.sh aarch64-unknown-linux-gnu clash-npm/platforms/linux-arm64 "$VERSION"

PACKAGES=(
  "clash-npm/platforms/darwin-arm64"
  "clash-npm/platforms/linux-x64"
  "clash-npm/platforms/linux-arm64"
  "clash-npm"
  "clash-pi"
)

publish_if_new() {
  local dir="$1"
  local name
  local version
  name=$(node -p "require('./$dir/package.json').name")
  version=$(node -p "require('./$dir/package.json').version")

  if npm view "$name@$version" version >/dev/null 2>&1; then
    echo "Skipping $name@$version (already published)"
    return 0
  fi

  echo "Publishing $name@$version from $dir"
  (cd "$dir" && npm publish --access public)
}

for pkg in "${PACKAGES[@]}"; do
  publish_if_new "$pkg"
done

echo "All packages published."
