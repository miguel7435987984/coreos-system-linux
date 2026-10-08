#!/usr/bin/env bash
set -e

DEST_DIR="${1:-/}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> Installing Prius Terminal to ${DEST_DIR}..."

install -d "${DEST_DIR}/usr/local/bin"
install -d "${DEST_DIR}/usr/share/applications"
install -d "${DEST_DIR}/usr/share/icons/hicolor/scalable/apps"

install -m 755 "${SRC_DIR}/apps/prius-terminal/prius" "${DEST_DIR}/usr/local/bin/prius"
install -m 644 "${SRC_DIR}/apps/prius-terminal/prius-terminal.desktop" "${DEST_DIR}/usr/share/applications/prius-terminal.desktop"
install -m 644 "${SRC_DIR}/branding/icons/prius-terminal.svg" "${DEST_DIR}/usr/share/icons/hicolor/scalable/apps/prius-terminal.svg"

# Set as default terminal alternative if update-alternatives exists
if [ -x "$(command -v update-alternatives)" ] && [ "${DEST_DIR}" = "/" ]; then
    update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/local/bin/prius 60 || true
fi

echo "==> Prius Terminal installed successfully!"
