#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
#  AEON Voice — Uninstall
# ═══════════════════════════════════════════════════════════

BIN_DIR="$HOME/.local/bin"
APP_NAME="AEON Voice"
INSTALL_DIR="$HOME/Applications"
LAUNCH_AGENT_ID="com.aeon.voice"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_ID.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "  $1"; }
ok()    { echo -e "  ${GREEN}✓${RESET} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${RESET} $1"; }

echo ""
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${BOLD}  AEON Voice — Uninstall${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo ""

# Stop the app if running
if pgrep -x "AEONVoice" &>/dev/null; then
    pkill -x "AEONVoice" 2>/dev/null || true
    ok "Stopped running AEON Voice"
fi

# Remove LaunchAgent
if [[ -f "$LAUNCH_AGENT_PLIST" ]]; then
    launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    rm -f "$LAUNCH_AGENT_PLIST"
    ok "Removed LaunchAgent"
fi

# Remove app bundle
if [[ -d "$INSTALL_DIR/$APP_NAME.app" ]]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    ok "Removed $INSTALL_DIR/$APP_NAME.app"
fi

# Remove voice scripts
VOICE_SCRIPTS=(
    aeon-voice-common
    aeon-voice
    aeon-prime-voice
    aeon-dev-voice
    aeon-voice-toggle
    aeon-voice-init
    aeon-voice-status
    aeon-voice-control
)

removed=0
for script in "${VOICE_SCRIPTS[@]}"; do
    if [[ -f "$BIN_DIR/$script" ]]; then
        rm -f "$BIN_DIR/$script"
        ((removed++))
    fi
done
ok "Removed $removed voice scripts from $BIN_DIR"

# Stop any playing audio
pkill -f "afplay /tmp/aeon-voice-" 2>/dev/null || true

# Clean temp files
find /tmp -name 'aeon-voice-*' -delete 2>/dev/null || true
ok "Cleaned temp files"

# Remove Copilot instruction file
COPILOT_FILE="$HOME/.copilot/instructions/aeon-voice.instructions.md"
if [[ -f "$COPILOT_FILE" ]]; then
    rm -f "$COPILOT_FILE"
    ok "Removed Copilot instruction file"
fi

# Remove config file
CONFIG_FILE="$HOME/.aeon-voice-config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
    ok "Removed config file"
fi

# Remove supplementary files
for f in "$HOME/.aeon-voice-python" "$HOME/.aeon-voice-notifications.jsonl" "$HOME/.aeon-voice-queue.lock"; do
    if [[ -f "$f" ]]; then
        rm -f "$f"
        ok "Removed $(basename "$f")"
    fi
done

# Note: we intentionally do NOT remove ~/.aeon-voice-enabled
# The user may want to preserve their preference.

echo ""
echo -e "${GREEN}${BOLD}  Uninstall complete.${RESET}"
echo ""
echo "  Note: ~/.aeon-voice-enabled was preserved."
echo "  To remove it: rm ~/.aeon-voice-enabled"
echo ""
