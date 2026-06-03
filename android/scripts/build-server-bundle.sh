#!/usr/bin/env bash
#
# Build the codex-web-local frontend and CLI, then copy them into
# APK assets so they can optionally be deployed without npm install.
#
# Usage:
#   ./scripts/build-server-bundle.sh
#
# Prerequisites:
#   - Node.js and npm installed on the build machine
#   - The codex-web-local source tree must live at
#       <project_root>/openclaw-android/
#     (this is the layout used by the AnyClaw repository).
#
# Run from the android/ directory OR the project root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ANDROID_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$ANDROID_DIR")"
CODEX_WEB_DIR="$PROJECT_ROOT/openclaw-android"

ASSETS_DIR="$ANDROID_DIR/app/src/main/assets/server-bundle"

# codex-web-local hosts the actual build scripts (build:frontend:bundle,
# build:cli) — the monorepo root does not.
if [ ! -d "$CODEX_WEB_DIR" ]; then
    echo "ERROR: codex-web-local source not found at $CODEX_WEB_DIR" >&2
    echo "       This script expects the codex-web-local tree to be a" >&2
    echo "       sibling of the android/ directory at the project root." >&2
    exit 1
fi

if [ ! -f "$CODEX_WEB_DIR/package.json" ]; then
    echo "ERROR: $CODEX_WEB_DIR/package.json missing — refusing to proceed." >&2
    exit 1
fi

echo "=== Building codex-web-local ==="
echo "Source: $CODEX_WEB_DIR"
echo "Assets: $ASSETS_DIR"

cd "$CODEX_WEB_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm install
fi

# Build frontend (Vue) and CLI (Express server)
# Use build:frontend:bundle to skip strict type checking so APK bundling
# isn't blocked by pre-existing source-code type errors. Run
# `npm run type-check` separately for the same coverage.
echo "Building frontend..."
npm run build:frontend:bundle

echo "Building CLI server..."
npm run build:cli

# Copy the built artifacts into assets
echo "Copying build artifacts to Android assets..."
rm -rf "$ASSETS_DIR"
mkdir -p "$ASSETS_DIR/dist"
mkdir -p "$ASSETS_DIR/dist-cli"

cp -r "$CODEX_WEB_DIR/dist/"* "$ASSETS_DIR/dist/"
cp -r "$CODEX_WEB_DIR/dist-cli/"* "$ASSETS_DIR/dist-cli/"
cp "$CODEX_WEB_DIR/package.json" "$ASSETS_DIR/package.json"

# Install production dependencies into the bundle
echo "Installing production dependencies for bundle..."
cd "$ASSETS_DIR"
npm install --omit=dev --ignore-scripts --no-audit --no-fund
cd "$CODEX_WEB_DIR"

echo ""
echo "=== Server bundle ready ==="
echo "Location: $ASSETS_DIR"
du -sh "$ASSETS_DIR" 2>/dev/null || true
