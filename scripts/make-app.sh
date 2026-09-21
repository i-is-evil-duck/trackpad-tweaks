#!/usr/bin/env bash
# Assemble TrackpadTweaks.app from the SwiftPM build and ad-hoc codesign it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-release}"
APP="${ROOT}/TrackpadTweaks.app"
BIN_NAME="TrackpadTweaks"

echo "[1/3] Building (${CONFIG})"
swift build -c "$CONFIG" --package-path "$ROOT"
BIN_PATH="$(swift build -c "$CONFIG" --package-path "$ROOT" --show-bin-path)/${BIN_NAME}"

echo "[2/3] Assembling ${APP}"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS"
cp "$BIN_PATH" "${APP}/Contents/MacOS/${BIN_NAME}"
cp "${ROOT}/Resources/Info.plist" "${APP}/Contents/Info.plist"

echo "[3/3] Codesigning"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP" 2>&1 | sed 's/^/  /'

echo "Built ${APP}"
echo "Run: open \"${APP}\" (move to /Applications for stable Launch at Login)"
