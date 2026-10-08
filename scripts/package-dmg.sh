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
    echo "[ERROR] Bundle ${APP_BUNDLE} belum dibangun. Jalankan ./scripts/build-intel.sh terlebih dahulu."
    exit 1
fi

echo "[DMG] Menyiapkan staging directory..."
rm -rf "${STAGING_DIR}" "${DMG_OUT}"
mkdir -p "${STAGING_DIR}"

# Salin aplikasi ke staging
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"

# Buat symlink ke direktori /Applications untuk drag-and-drop installer standar macOS
ln -s /Applications "${STAGING_DIR}/Applications"

echo "[DMG] Membuat disk image (.dmg)..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_OUT}"

rm -rf "${STAGING_DIR}"

echo "[SELESAI] File DMG installer berhasil dibuat di:"
ls -lh "${DMG_OUT}"
