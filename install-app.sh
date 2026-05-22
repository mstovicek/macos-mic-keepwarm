#!/bin/bash
# install-app.sh
# Downloads and installs mic-warm-app (menu bar toggle) as a persistent LaunchAgent.

set -e

REPO="drewburchfield/macos-mic-keepwarm"
APP_DIR="/Applications"
APP_PATH="$APP_DIR/Mic Warm.app"
BIN_PATH="$APP_PATH/Contents/MacOS/mic-warm-app"
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.mic-warm-app.plist"

echo "Installing mic-warm-app..."

# Stop any running instance
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -x mic-warm-app 2>/dev/null || true
pkill -x mic-warm 2>/dev/null || true

mkdir -p "$APP_DIR"
rm -rf "$APP_PATH"

# Download and unzip the .app bundle
TMP_ZIP=$(mktemp /tmp/mic-warm-app.XXXXXX.zip)
curl -fsSL "https://github.com/$REPO/releases/latest/download/mic-warm-app.zip" -o "$TMP_ZIP"
unzip -q "$TMP_ZIP" -d "$APP_DIR"
rm "$TMP_ZIP"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: expected '$APP_PATH' after unzip but it was not found."
    echo "The release zip may have an unexpected structure."
    exit 1
fi

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
echo "To uninstall: curl -fsSL https://raw.githubusercontent.com/drewburchfield/macos-mic-keepwarm/master/uninstall.sh | bash"
