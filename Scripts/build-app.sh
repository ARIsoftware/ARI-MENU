#!/bin/bash
# Build ARIMenu.app — compiles the Swift binary and wraps it in a proper
# macOS .app bundle (Info.plist with LSUIElement so it lives in the menu bar
# only, no Dock icon).
set -euo pipefail

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$ROOT"

APP_NAME="ARIMenu"
BUNDLE_ID="ari.software.menu"
VERSION="0.1.0"
APP_DIR="$ROOT/$APP_NAME.app"

echo "▸ swift build -c release"
# Single-arch native build. Works with Command Line Tools.
# For a universal binary (distribute to Intel + Apple Silicon), append:
#   --arch arm64 --arch x86_64
# but that requires full Xcode (xcbuild), not just CLT.
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
  echo "✘ Binary not found at $BIN_PATH"
  exit 1
fi

echo "▸ Assembling $APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>ARI Menu</string>
    <key>CFBundleDisplayName</key>
    <string>ARI Menu</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Panthera Ventures Inc. d/b/a ARI.Software</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Ad-hoc sign so the app can use SMAppService / NSStatusItem on modern macOS
# without Gatekeeper interruptions when launched locally.
echo "▸ Ad-hoc codesign"
codesign --force --deep --sign - "$APP_DIR" || {
  echo "⚠ codesign failed — app may still run but may show security warnings"
}

echo "✓ Built $APP_DIR"
echo ""
echo "  Drag to /Applications (or run directly):"
echo "    open \"$APP_DIR\""
