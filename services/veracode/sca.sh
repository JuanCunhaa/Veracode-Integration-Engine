#!/usr/bin/env bash
# Explicação: Executa Veracode SCA Agent-Based usando o script oficial de CI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"

ci_debug

TOKEN="${SRCCLR_API_TOKEN:-${SCA_TOKEN:-}}"
if [[ -z "${TOKEN}" ]]; then
  fail "❌ Erro: scaToken não informado. Adicione via secrets.SRCCLR_API_TOKEN (ou scaToken)."
fi

export SRCCLR_API_TOKEN="${TOKEN}"

log_step "🧪 Iniciando Veracode SCA (Agent-Based)..."

# Baixa e executa o script oficial de CI do SourceClear/Veracode SCA
# Referência: https://download.sourceclear.com/ci.sh

curl -sSfL https://sca-downloads.veracode.com/ci.sh -o /tmp/srcclr_ci.sh || \
curl -sSL https://download.sourceclear.com/ci.sh -o /tmp/srcclr_ci.sh
chmod +x /tmp/srcclr_ci.sh

SCA_ARGS=(scan)

if [[ "${DEBUG_LOG:-false}" == "true" ]]; then
  SCA_ARGS+=(--debug)
fi

# Preferência: saída somente console, sem gráficos/artefatos
SCA_ARGS+=(--no-graphs)

log_info "Executando: srcclr ${SCA_ARGS[*]}"
"/tmp/srcclr_ci.sh" "${SCA_ARGS[@]}"

log_ok "SCA concluído. Consulte o log acima para detalhes."
