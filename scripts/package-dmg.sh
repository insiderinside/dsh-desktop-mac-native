#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

APP_NAME="DeepSeek Harness"
APP_BUNDLE="${ROOT_DIR}/dist/DSHDesktop.app"
DMG_OUT="${ROOT_DIR}/dist/${APP_NAME}.dmg"
STAGING_DIR="${ROOT_DIR}/dist/dmg_staging"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "[ERROR] Bundle ${APP_BUNDLE} has not been built yet. Run ./scripts/build-intel.sh or ./scripts/build-universal.sh first."
    exit 1
fi

echo "[DMG] Setting up staging directory..."
rm -rf "${STAGING_DIR}" "${DMG_OUT}"
mkdir -p "${STAGING_DIR}"

# Copy app bundle to staging
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"

# Create symlink to /Applications for standard drag-and-drop installer
ln -s /Applications "${STAGING_DIR}/Applications"

echo "[DMG] Creating disk image (.dmg)..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_OUT}"

rm -rf "${STAGING_DIR}"

echo "[DONE] Distributable DMG created at:"
ls -lh "${DMG_OUT}"
