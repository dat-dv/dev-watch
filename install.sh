#!/usr/bin/env bash

# install.sh
# One-line installer for DevWatch on macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/<username>/dev-watch/main/install.sh | bash

set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/devwatch"
RAW_URL="https://raw.githubusercontent.com/datdoan/dev-watch/main/devwatch.sh"

echo "⚡ Installing DevWatch..."

mkdir -p "$INSTALL_DIR"

if [ -f "devwatch.sh" ]; then
  if [ "$(realpath "$BIN_PATH" 2>/dev/null || true)" != "$(realpath "devwatch.sh" 2>/dev/null || true)" ]; then
    cp -f "devwatch.sh" "$BIN_PATH"
  fi
else
  curl -fsSL "$RAW_URL" -o "$BIN_PATH"
fi

chmod +x "$BIN_PATH"

echo "✓ Installed 'devwatch' CLI to $BIN_PATH"

# Build DevWatch.app for macOS Applications
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "🍏 Building DevWatch.app for /Applications..."
  TMP_DIR="$(mktemp -d)"
  TMP_APP="$TMP_DIR/DevWatch.app"

  osacompile -o "$TMP_APP" -e '
  set appPath to POSIX path of (path to me)
  set shPath to appPath & "Contents/Resources/devwatch.sh"
  tell application "Terminal"
      activate
      set win to do script quote & shPath & quote
      tell win
          set number of columns to 110
          set number of rows to 24
      end tell
  end tell
  ' 2>/dev/null || true

  if [ -d "$TMP_APP" ]; then
    mkdir -p "$TMP_APP/Contents/Resources"
    cp "$BIN_PATH" "$TMP_APP/Contents/Resources/devwatch.sh"
    chmod +x "$TMP_APP/Contents/Resources/devwatch.sh"
    rm -rf /Applications/DevWatch.app
    cp -R "$TMP_APP" /Applications/
    rm -rf "$TMP_DIR"
    echo "✓ Installed DevWatch.app to /Applications"
  fi
fi

echo ""
echo "🎉 Installation complete! Run 'devwatch' in any terminal."
