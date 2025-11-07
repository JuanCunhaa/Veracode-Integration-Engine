#!/usr/bin/env bash
# Explicação: Garante que a Veracode CLI esteja instalada e disponível no PATH.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v veracode >/dev/null 2>&1; then
  exit 0
fi

bash "$SCRIPT_DIR/install_veracode_cli.sh"

if ! command -v veracode >/dev/null 2>&1; then
  echo "❌ Veracode CLI não encontrada após tentativa de instalação." >&2
  exit 1
fi

