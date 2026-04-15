#!/usr/bin/env bash
set -euo pipefail

# Usage: prepare-platform.sh <rust-target> <platform-dir> <version>
# Downloads the release tarball for <rust-target> at version v<version> from
# GitHub Releases and extracts the clash binary into <platform-dir>.
#
# Example: prepare-platform.sh aarch64-apple-darwin clash-npm/platforms/darwin-arm64 0.6.2

RUST_TARGET="$1"
PLATFORM_DIR="$2"
VERSION="$3"

TAG="v${VERSION}"
TARBALL_URL="https://github.com/empathic/clash/releases/download/${TAG}/clash-${RUST_TARGET}.tar.gz"
TARBALL="$(mktemp -t clash-${RUST_TARGET}.XXXXXX.tar.gz)"

trap 'rm -f "$TARBALL"' EXIT

echo "Downloading $TARBALL_URL"
curl -fsSL "$TARBALL_URL" -o "$TARBALL"

tar xzf "$TARBALL" -C "$PLATFORM_DIR"

if [ ! -f "$PLATFORM_DIR/clash" ]; then
  echo "ERROR: clash binary not found in $PLATFORM_DIR after extraction"
  exit 1
fi

chmod 755 "$PLATFORM_DIR/clash"
echo "Prepared $PLATFORM_DIR/clash from $TAG"
