#!/usr/bin/env bash
set -euo pipefail

# Publish all npm packages in the correct order, skipping any version
# that is already published on the registry. Idempotent on workflow retries.

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
