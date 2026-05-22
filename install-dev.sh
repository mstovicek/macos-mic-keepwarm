#!/bin/bash
# install-dev.sh
# Builds mic-warm-app from source and installs as a persistent LaunchAgent.
# For local development and testing. End users should use install-app.sh instead.
# Run from the repo root: bash install-dev.sh

set -e

APP_DIR="/Applications"
APP_PATH="$APP_DIR/Mic Warm.app"
BIN_PATH="$APP_PATH/Contents/MacOS/mic-warm-app"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.mic-warm-app.plist"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Building mic-warm-app..."
cd "$REPO_DIR"
swift build -c release 2>&1

# Prefer universal build output (--arch arm64 --arch x86_64), fall back to single-arch
BUILT_BIN="$REPO_DIR/.build/apple/Products/Release/mic-warm-app"
if [ ! -f "$BUILT_BIN" ]; then
    BUILT_BIN="$REPO_DIR/.build/release/mic-warm-app"
fi

# Stop any running instance
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x mic-warm-app 2>/dev/null || true
pkill -x mic-warm 2>/dev/null || true
sleep 0.5

# Generate app icon if not present (excluded from repo, generated at build time)
if [ ! -f "$REPO_DIR/Sources/MicWarmApp/Resources/AppIcon.icns" ]; then
    echo "Generating app icon..."
    swift "$REPO_DIR/generate-icon.sh"
fi

# Assemble .app bundle
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
cp "$BUILT_BIN" "$APP_PATH/Contents/MacOS/mic-warm-app"
cp "$REPO_DIR/Sources/MicWarmApp/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$REPO_DIR/Sources/MicWarmApp/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"

# Ad-hoc code sign so macOS TCC tracks a stable identity
codesign --force --sign - "$APP_PATH"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mic-warm-app</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BIN_PATH}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardErrorPath</key>
    <string>/tmp/mic-warm.log</string>
    <key>StandardOutPath</key>
    <string>/tmp/mic-warm.log</string>
</dict>
</plist>
EOF

launchctl load "$PLIST_PATH"

echo ""
echo "Installed and running."
echo "The Mic Warm menu bar icon should appear shortly."
echo ""
echo "If you haven't granted mic access yet:"
echo "  System Settings > Privacy & Security > Microphone > allow Mic Warm"
echo ""
echo "To relaunch after quitting: Spotlight (Cmd+Space) → 'Mic Warm'"
echo "Log file: /tmp/mic-warm.log"
echo "To uninstall: bash $REPO_DIR/uninstall.sh"
