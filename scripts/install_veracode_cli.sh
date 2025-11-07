#!/usr/bin/env bash
# Explicação: Instala a Veracode CLI e adiciona ao PATH em ambientes compatíveis.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

INSTALL_BASE="${RUNNER_TEMP:-/tmp}/veracode-cli"

log_step "🔧 Instalando Veracode CLI..."
ci_debug

rm -rf "$INSTALL_BASE" || true
mkdir -p "$INSTALL_BASE"
pushd "$INSTALL_BASE" >/dev/null

OS_NAME="$(uname -s || echo unknown)"
case "$OS_NAME" in
  Linux|Darwin)
    if ! command -v curl >/dev/null 2>&1; then
      fail "❌ 'curl' não encontrado no runner."
    fi
    set +e
    curl -fsS https://tools.veracode.com/veracode-cli/install | sh
    status=$?
    set -e
    if [[ $status -ne 0 ]]; then
      fail "❌ Falha ao instalar a Veracode CLI via script oficial (sh)."
    fi
    if [[ -x "$INSTALL_BASE/veracode" ]]; then
      VERACODE_BIN_DIR="$INSTALL_BASE"
    else
      VERACODE_BIN_DIR=$(dirname "$(find "$INSTALL_BASE" -type f -name veracode -maxdepth 3 | head -n1 2>/dev/null || true)")
    fi
    if [[ -n "${VERACODE_BIN_DIR:-}" && -x "$VERACODE_BIN_DIR/veracode" ]]; then
      echo "$VERACODE_BIN_DIR" >> "$GITHUB_PATH"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    if command -v powershell >/dev/null 2>&1; then
      set +e
      powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& { iwr -UseBasicParsing https://tools.veracode.com/veracode-cli/install.ps1 | iex }"
      status=$?
      set -e
      if [[ $status -ne 0 ]]; then
        fail "❌ Falha ao instalar a Veracode CLI via script oficial (install.ps1)."
      fi
      : # confiar no PATH do instalador no Windows
    else
      fail "❌ PowerShell não disponível para instalar a Veracode CLI no Windows."
    fi
    ;;
  *)
    log_info "Sistema operacional ($OS_NAME) não suportado para instalação automática."
    ;;
esac

if command -v veracode >/dev/null 2>&1; then
  veracode version || true
  log_ok "Veracode CLI instalada e disponível no PATH."
else
  fail "❌ Veracode CLI não localizada após instalação."
fi

popd >/dev/null
