#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -m 0755 "${SCRIPT_DIR}/get-install" /usr/local/bin/get-install
echo "    ✓ get-install instalado em /usr/local/bin/get-install"
