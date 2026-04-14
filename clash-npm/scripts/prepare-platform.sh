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

if [ ! -f "$PLATFORM_DIR/clash" ]; then
  echo "ERROR: clash binary not found in $PLATFORM_DIR after extraction"
  exit 1
fi

chmod 755 "$PLATFORM_DIR/clash"
echo "Prepared $PLATFORM_DIR/clash from $TARBALL"
