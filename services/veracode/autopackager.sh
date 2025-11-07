#!/usr/bin/env bash
# Explicação: Executa o Auto Packager via Veracode CLI e gera veracode_package.zip.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

WORKDIR="${GITHUB_WORKSPACE:-$(pwd)}"
PKG_NAME="veracode_package.zip"

log_step "🧰 Executando Veracode Auto Packager..."
ci_debug

rm -f "$PKG_NAME" || true

bash "$SCRIPT_DIR/../../scripts/ensure_veracode_cli.sh"

set +e
veracode package --source "." --output "$PKG_NAME"
status=$?
set -e
if [[ $status -ne 0 ]]; then
  fail "❌ Falha no Auto Packager via Veracode CLI. Verifique logs acima."
fi

assert_artifact_exists "$PKG_NAME"
log_ok "Pacote criado com sucesso via Veracode CLI: $PKG_NAME"
