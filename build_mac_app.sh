#!/usr/bin/env bash

# build_mac_app.sh
# Bundles devwatch.sh into a standalone DevWatch.app for macOS and creates global CLI command (devwatch)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="DevWatch.app"
APP_PATH="${SCRIPT_DIR}/${APP_NAME}"
TARGET_APPS="/Applications"

echo "Creating ${APP_NAME}..."

# 1. Compile AppleScript launcher into .app bundle
osacompile -o "${APP_PATH}" -e '
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
'

# 2. Copy devwatch.sh into App Resources bundle
mkdir -p "${APP_PATH}/Contents/Resources"
cp "${SCRIPT_DIR}/devwatch.sh" "${APP_PATH}/Contents/Resources/devwatch.sh"
chmod +x "${APP_PATH}/Contents/Resources/devwatch.sh"

# 3. Auto-install to /Applications
echo "Installing ${APP_NAME} to ${TARGET_APPS}..."
rm -rf "${TARGET_APPS}/${APP_NAME}" "${TARGET_APPS}/AgentWatch.app"
cp -R "${APP_PATH}" "${TARGET_APPS}/"

# 4. Create global CLI symlink (~/.local/bin/devwatch)
mkdir -p "$HOME/.local/bin"
ln -sf "${SCRIPT_DIR}/devwatch.sh" "$HOME/.local/bin/devwatch"

echo "✓ Successfully built and installed ${APP_NAME} into /Applications!"
echo "✓ Created global CLI command 'devwatch' in ~/.local/bin"
