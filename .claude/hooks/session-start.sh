#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.5"
GODOT_DIR="$HOME/.local/godot"
GODOT_BIN="$GODOT_DIR/godot"

# Godot binary: install once, cached across sessions via container state.
if [ ! -x "$GODOT_BIN" ] || ! "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION}\."; then
  mkdir -p "$GODOT_DIR"
  tmp="$(mktemp -d)"
  curl -sSL -o "$tmp/godot.zip" \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -q "$tmp/godot.zip" -d "$tmp"
  mv "$tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$GODOT_BIN"
  rm -rf "$tmp"
fi

# xvfb + a software GL driver: tests/playtest.gd needs a real display to
# play scripted scenarios and save screenshots.
if ! command -v xvfb-run >/dev/null 2>&1; then
  apt-get update -q
  apt-get install -y -q xvfb libgl1-mesa-dri
fi

echo "export PATH=\"$GODOT_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# The import pass builds the class_name cache the scripts rely on; later
# test and playtest runs need it to already exist.
"$GODOT_BIN" --headless --path "$CLAUDE_PROJECT_DIR" --import
