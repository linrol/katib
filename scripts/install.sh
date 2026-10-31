#!/usr/bin/env bash
set -e

APP_NAME="Katib"
BUNDLE_ID="com.linrol.katib"
INSTALL_DIR="/Applications/${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "  📦 Building & Installing ${APP_NAME} ...  "
echo "=========================================="

cd "${ROOT_DIR}"

# Build release executable
swift build -c release

BIN_PATH="${ROOT_DIR}/.build/release/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
    echo "❌ Build failed: executable not found at ${BIN_PATH}"
    exit 1
fi

# Kill running instance if exists
pkill -x "${APP_NAME}" 2>/dev/null || true

# Prepare .app bundle structure
STAGING_DIR="/tmp/${APP_NAME}_bundle"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}/Contents/MacOS"
mkdir -p "${STAGING_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${STAGING_DIR}/Contents/MacOS/${APP_NAME}"

# Generate Info.plist
cat <<EOF > "${STAGING_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.2</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSScreenCaptureUsageDescription</key>
    <string>Katib needs screen recording permission to capture and transcribe incoming system meeting audio without using the microphone.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Katib needs microphone access to transcribe your voice during meetings.</string>
</dict>
</plist>
EOF

# Copy to /Applications
rm -rf "${INSTALL_DIR}"
cp -R "${STAGING_DIR}" "${INSTALL_DIR}"
rm -rf "${STAGING_DIR}"

# Sign app bundle
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Teams Wake Dev" | head -1 | awk -F '"' '{print $2}')
if [ -z "${SIGNING_IDENTITY}" ]; then
    SIGNING_IDENTITY="-"
fi

codesign --force --deep --sign "${SIGNING_IDENTITY}" "${INSTALL_DIR}"

echo "=========================================="
echo "  🎉 Installed to ${INSTALL_DIR}"
echo "=========================================="

