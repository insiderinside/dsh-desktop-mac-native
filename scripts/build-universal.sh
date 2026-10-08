#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "[BUILD] Mengompilasi DSHDesktop Universal 2 (x86_64 & arm64)..."

# Build untuk arsitektur host (x86_64)
echo "  -> Building x86_64..."
swift build -c release --arch x86_64

# Build untuk target Apple Silicon (arm64)
echo "  -> Building arm64..."
swift build -c release --arch arm64

X86_BIN="${ROOT_DIR}/.build/x86_64-apple-macosx/release/DSHDesktop"
ARM_BIN="${ROOT_DIR}/.build/arm64-apple-macosx/release/DSHDesktop"

OUT_DIR="${ROOT_DIR}/dist"
APP_DIR="${OUT_DIR}/DSHDesktop.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "[LIPO] Menggabungkan binary universal..."
lipo -create -output "${MACOS_DIR}/DSHDesktop" "${X86_BIN}" "${ARM_BIN}"

cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
if [ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
fi

echo "[VERIFIKASI] Memeriksa arsitektur binary..."
file "${MACOS_DIR}/DSHDesktop"

echo "[SELESAI] Bundle berhasil dibuat di: ${APP_DIR}"
