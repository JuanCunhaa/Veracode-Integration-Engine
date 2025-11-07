#!/usr/bin/env bash
# Explicação: Executa varredura IaC, Contêiner e Segredos via Veracode CLI com saída somente em logs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"

ci_debug

VID="${VERACODE_API_ID:-}"; VKEY="${VERACODE_API_KEY:-}"
[[ -z "$VID" ]] && fail "❌ Erro: veracodeApiId não informado. Adicione via secrets.VERACODE_API_ID."
[[ -z "$VKEY" ]] && fail "❌ Erro: veracodeApiKey não informado. Adicione via secrets.VERACODE_API_KEY."

SOURCE_DIR="${IAC_SOURCE:-${PWD}}"
TYPE="${IAC_TYPE:-directory}"
FORMAT="${IAC_FORMAT:-table}"
FAIL_BUILD="${IAC_FAIL_BUILD:-false}"
DEBUG_VAL="${DEBUG_LOG:-false}"

log_step "🏗️ Executando Veracode IaC/Container/Secrets Scan..."

bash "$SCRIPT_DIR/../../scripts/ensure_veracode_cli.sh"

log_info "Veracode CLI detectada. Executando varredura IaC/Container/Secrets..."
set +e
export VERACODE_API_KEY_ID="$VID"
export VERACODE_API_KEY_SECRET="$VKEY"
veracode scan --type "$TYPE" --source "$SOURCE_DIR" --format "$FORMAT" $([[ "$DEBUG_VAL" == "true" ]] && echo "--debug")
status=$?
set -e
if [[ $status -ne 0 ]]; then
  if [[ "$FAIL_BUILD" == "true" ]]; then
    fail "❌ IaC Scan encontrou problemas."
  else
    log_err "IaC Scan encontrou problemas, mas não falhará o job (fail_build=false)."
  fi
fi
log_ok "IaC Scan finalizado."
