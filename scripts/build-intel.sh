#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "[BUILD] Mengompilasi DSHDesktop untuk arsitektur lokal (x86_64 Intel Mac)..."
swift build -c release --arch x86_64

BIN_SRC="${ROOT_DIR}/.build/x86_64-apple-macosx/release/DSHDesktop"
OUT_DIR="${ROOT_DIR}/dist"
APP_DIR="${OUT_DIR}/DSHDesktop.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_SRC}" "${MACOS_DIR}/DSHDesktop"
cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

if [ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

echo "[VERIFIKASI] Memeriksa binary:"
file "${MACOS_DIR}/DSHDesktop"
echo "[SELESAI] Bundle siap di: ${APP_DIR}"
