#!/bin/bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════
#  AEON Voice — Remote Installer
#  curl -fsSL https://raw.githubusercontent.com/ekeng92/aeon-voice/main/scripts/remote-install.sh | bash
# ═══════════════════════════════════════════════════════════

REPO="https://github.com/ekeng92/aeon-voice.git"
CLONE_DIR="${TMPDIR:-/tmp}/aeon-voice-install"

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
echo -e "${BOLD}  AEON Voice — Installer${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo ""

# ── Preflight ──────────────────────────────────────────────

info "Checking requirements..."

# macOS only
[[ "$(uname -s)" == "Darwin" ]] || fail "AEON Voice requires macOS."

# macOS 13+
MACOS_VERSION="$(sw_vers -productVersion)"
MAJOR="$(echo "$MACOS_VERSION" | cut -d. -f1)"
(( MAJOR >= 13 )) || fail "macOS 13+ required. You have $MACOS_VERSION."

# Swift — trigger install dialog if missing (user must re-run after)
if ! command -v swift &>/dev/null; then
    echo ""
    warn "Swift not found. Installing Xcode CommandLineTools..."
    echo "  A system dialog may appear. Click 'Install' and wait."
    echo ""
    xcode-select --install 2>/dev/null || true
    echo ""
    echo "  After installation completes, re-run this script:"
    echo ""
    echo "    curl -fsSL https://raw.githubusercontent.com/ekeng92/aeon-voice/main/scripts/remote-install.sh | bash"
    echo ""
    exit 0
fi

# Python 3
command -v python3 &>/dev/null || fail "Python 3 not found. Install via: brew install python3"

# Git
command -v git &>/dev/null || fail "Git not found."

ok "All prerequisites met"

# ── Clone ──────────────────────────────────────────────────

info "Downloading AEON Voice..."
rm -rf "$CLONE_DIR"
git clone --depth 1 "$REPO" "$CLONE_DIR" 2>/dev/null
ok "Downloaded"

# ── Install ────────────────────────────────────────────────

cd "$CLONE_DIR"
bash scripts/install.sh "$@"

# ── Cleanup ────────────────────────────────────────────────

rm -rf "$CLONE_DIR"
