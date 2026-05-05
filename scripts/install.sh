#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
#  AEON Voice — Complete Installation
#  Works on any Mac with macOS 13+ and Xcode CommandLineTools
# ═══════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Support AEON_PREFIX for dry-run / sandboxed installs
AEON_HOME="${AEON_PREFIX:-$HOME}"
BIN_DIR="$AEON_HOME/.local/bin"
FLAG_FILE="$AEON_HOME/.aeon-voice-enabled"
APP_NAME="AEON Voice"
INSTALL_DIR="$AEON_HOME/Applications"
LAUNCH_AGENT_DIR="$AEON_HOME/Library/LaunchAgents"
LAUNCH_AGENT_ID="com.aeon.voice"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/$LAUNCH_AGENT_ID.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { echo -e "${CYAN}▸${RESET} $1"; }
ok()    { echo -e "${GREEN}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $1"; }
fail()  { echo -e "${RED}✗${RESET} $1"; exit 1; }

echo ""
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${BOLD}  AEON Voice — Installation${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo ""

if [[ -n "${AEON_PREFIX:-}" ]]; then
    warn "DRY RUN MODE — installing to $AEON_HOME (not your real home)"
    echo ""
fi

# ── Step 1: Check macOS version ────────────────────────────────────────

info "Checking macOS version..."
MACOS_VERSION="$(sw_vers -productVersion)"
MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"
if (( MAJOR < 13 )); then
    fail "macOS 13 (Ventura) or later required. You have $MACOS_VERSION."
fi
ok "macOS $MACOS_VERSION"

# ── Step 2: Check Swift toolchain ──────────────────────────────────────

info "Checking Swift toolchain..."
if ! command -v swift &>/dev/null; then
    fail "Swift not found. Install Xcode CommandLineTools: xcode-select --install"
fi
SWIFT_VERSION="$(swift --version 2>&1 | head -1)"
ok "$SWIFT_VERSION"

# ── Step 3: Check Python 3 ────────────────────────────────────────────

info "Checking Python 3..."
if ! command -v python3 &>/dev/null; then
    fail "Python 3 not found. Install via: brew install python3"
fi
PYTHON_VERSION="$(python3 --version 2>&1)"
ok "$PYTHON_VERSION"

# ── Step 4: Check / install edge-tts ──────────────────────────────────

info "Checking edge-tts..."
if python3 -m edge_tts --help &>/dev/null; then
    ok "edge-tts available"
else
    warn "edge-tts not found. Installing..."
    python3 -m pip install --user edge-tts --quiet 2>/dev/null || python3 -m pip install edge-tts --quiet --break-system-packages 2>/dev/null || pip3 install edge-tts --quiet
    if python3 -m edge_tts --help &>/dev/null; then
        ok "edge-tts installed"
    else
        fail "edge-tts installation failed. Try: pip3 install edge-tts"
    fi
fi

# ── Step 5: Build the app ─────────────────────────────────────────────

info "Building AEON Voice (compiling from source — this takes 1–2 minutes)..."
cd "$PROJECT_DIR"
make app
echo ""

# ── Step 6: Install app bundle ────────────────────────────────────────

info "Installing app to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
if pgrep -x AEONVoice >/dev/null 2>&1; then
    info "Quitting running AEON Voice before replacing the app..."
    osascript -e 'quit app "AEON Voice"' >/dev/null 2>&1 || pkill -x AEONVoice 2>/dev/null || true
    sleep 1
fi
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "build/$APP_NAME.app" "$INSTALL_DIR/"
if [[ -f "$PROJECT_DIR/resources/AppIcon.icns" ]]; then
    mkdir -p "$INSTALL_DIR/$APP_NAME.app/Contents/Resources"
    cp "$PROJECT_DIR/resources/AppIcon.icns" "$INSTALL_DIR/$APP_NAME.app/Contents/Resources/"
fi
codesign --force --deep --sign - "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
touch "$INSTALL_DIR/$APP_NAME.app"
rm -rf "$PROJECT_DIR/build" 2>/dev/null || true
ok "App installed: $INSTALL_DIR/$APP_NAME.app"

# ── Step 7: Install voice scripts ─────────────────────────────────────

info "Installing voice scripts to $BIN_DIR..."
mkdir -p "$BIN_DIR"

VOICE_SCRIPTS=(
    aeon-voice-common
    aeon-voice
    aeon-prime-voice
    aeon-dev-voice
    aeon-voice-toggle
    aeon-voice-init
    aeon-voice-status
)

for script in "${VOICE_SCRIPTS[@]}"; do
    cp "$PROJECT_DIR/scripts/voice/$script" "$BIN_DIR/$script"
    chmod +x "$BIN_DIR/$script"
done

# Create convenience launcher
cat > "$BIN_DIR/aeon-voice-control" << LAUNCHER
#!/bin/zsh
open "$INSTALL_DIR/$APP_NAME.app"
LAUNCHER
chmod +x "$BIN_DIR/aeon-voice-control"

ok "Voice scripts installed (${#VOICE_SCRIPTS[@]} scripts + launcher)"

# ── Step 8: Initialize flag file ──────────────────────────────────────

if [[ ! -f "$FLAG_FILE" ]]; then
    printf 'on\n' > "$FLAG_FILE"
    chmod 600 "$FLAG_FILE" 2>/dev/null || true
    ok "Voice flag created: $FLAG_FILE (on)"
else
    CURRENT="$(tr -d '[:space:]' < "$FLAG_FILE")"
    ok "Voice flag exists: $FLAG_FILE ($CURRENT)"
fi

# ── Step 9: Ensure ~/.local/bin is in PATH ────────────────────────────

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in PATH"
    echo ""
    echo "  Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo ""
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

# ── Step 10: Optional LaunchAgent (auto-start on login) ───────────────

if [[ -n "${AEON_PREFIX:-}" ]]; then
    info "Skipping LaunchAgent (dry-run mode)"
    REPLY="n"
else
    echo ""
    read -p "  Start AEON Voice automatically on login? [y/N] " -n 1 -r < /dev/tty
    echo ""
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$LAUNCH_AGENT_DIR"
    cat > "$LAUNCH_AGENT_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LAUNCH_AGENT_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$APP_NAME.app/Contents/MacOS/AEONVoice</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PLIST"
    ok "LaunchAgent installed — AEON Voice will start on login"
else
    info "Skipped LaunchAgent. Start manually: open '$INSTALL_DIR/$APP_NAME.app'"
fi

# ── Step 11: VS Code Copilot integration ──────────────────────────────

COPILOT_DIR="$AEON_HOME/.copilot/instructions"
COPILOT_FILE="$COPILOT_DIR/aeon-voice.instructions.md"
SOURCE_INSTRUCTION="$PROJECT_DIR/examples/aeon-voice.instructions.md"

echo ""
echo -e "${CYAN}  VS Code Copilot Integration${RESET}"
echo ""
echo "  AEON Voice can teach your AI agents (GitHub Copilot, Claude, etc.)"
echo "  when and how to speak. This installs a global instruction file that"
echo "  applies across all your VS Code workspaces."
echo ""
echo "  Location: $COPILOT_FILE"
echo "  You can edit it anytime to customize voice behavior."
echo ""

if [[ -f "$COPILOT_FILE" ]]; then
    warn "Copilot instruction file already exists at $COPILOT_FILE"
    read -p "  Overwrite with latest version? [y/N] " -n 1 -r < /dev/tty
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp "$SOURCE_INSTRUCTION" "$COPILOT_FILE"
        ok "Copilot instruction file updated"
        OPEN_INSTRUCTION=true
    else
        info "Kept existing instruction file"
        OPEN_INSTRUCTION=false
    fi
else
    read -p "  Enable AI agent voice in VS Code? [Y/n] " -n 1 -r < /dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        mkdir -p "$COPILOT_DIR"
        cp "$SOURCE_INSTRUCTION" "$COPILOT_FILE"
        ok "Copilot instruction file installed"
        OPEN_INSTRUCTION=true
    else
        info "Skipped Copilot integration. You can add it later:"
        echo "    cp examples/aeon-voice.instructions.md ~/.copilot/instructions/"
        OPEN_INSTRUCTION=false
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Installation complete!${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo ""
echo "  App:      $INSTALL_DIR/$APP_NAME.app"
echo "  Scripts:  $BIN_DIR/aeon-*"
echo "  Flag:     $FLAG_FILE"
if [[ -f "$COPILOT_FILE" ]]; then
echo "  Copilot:  $COPILOT_FILE"
fi
echo ""
echo "  Launch:   open '$INSTALL_DIR/$APP_NAME.app'"
echo "  CLI:      aeon-voice-control"
echo ""

# Open the instruction file in VS Code so the user can review/customize it
if [[ "$OPEN_INSTRUCTION" == "true" ]] && command -v code &>/dev/null; then
    echo "  Opening instruction file in VS Code..."
    code "$COPILOT_FILE"
fi
