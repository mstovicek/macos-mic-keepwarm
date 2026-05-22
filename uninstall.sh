#!/bin/bash
# uninstall.sh
# Removes the mic-warm background service.

set -e

DAEMON_PLIST="$HOME/Library/LaunchAgents/com.user.keep-mic-warm.plist"
APP_PLIST="$HOME/Library/LaunchAgents/com.user.mic-warm-app.plist"

uninstalled=false
for PLIST_PATH in "$DAEMON_PLIST" "$APP_PLIST"; do
    if [ -f "$PLIST_PATH" ]; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        rm -f "$PLIST_PATH"
        uninstalled=true
    fi
done
if $uninstalled; then
    echo "Uninstalled. Mic will return to default sleep behavior."
else
    echo "mic-warm is not installed (no plist found)."
fi

pkill -x mic-warm-app 2>/dev/null || true
pkill -x mic-warm 2>/dev/null || true

rm -f /tmp/mic-warm.pid
rm -f /tmp/mic-warm-app.pid
rm -f /tmp/mic-warm.log

if [ -f "$HOME/.local/bin/mic-warm" ]; then
    rm -f "$HOME/.local/bin/mic-warm"
    echo "Removed mic-warm binary."
fi

if [ -f "$HOME/.local/bin/mic-warm-app" ]; then
    rm -f "$HOME/.local/bin/mic-warm-app"
    echo "Removed mic-warm-app binary."
fi

if [ -d "/Applications/Mic Warm.app" ]; then
    rm -rf "/Applications/Mic Warm.app"
    echo "Removed Mic Warm.app."
fi
