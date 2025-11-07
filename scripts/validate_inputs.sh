#!/usr/bin/env bash
# Explicação: Valida inputs e secrets, garante coerência entre flags e falha cedo com mensagens claras.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

log_step "Iniciando validação de parâmetros..."

if [[ -z "${INPUTS_JSON:-}" ]]; then
  fail "Entrada 'INPUTS_JSON' não foi fornecida ao validador."
fi

py() {
  python3 - "$@" << 'PY'
import json, os, sys
data=json.loads(os.environ.get('INPUTS_JSON','{}'))
def g(k, d=''):
    v=data.get(k, d)
    if isinstance(v, bool):
        print('true' if v else 'false')
    else:
        print(str(v))
for k in sys.argv[1:]:
    g(k)
PY
}

get_bool() { [[ "$(py "$1")" == "true" ]]; }

ENABLE_SCA=$(py enableSCA)
ENABLE_US=$(py enableUS)
ENABLE_PS=$(py enablePS)
ENABLE_IAC=$(py enableIAC)
ENABLE_AP=$(py enableAP)

JAVA=$(py java)
DOTNET=$(py dotnet)
GRADLE=$(py gradle)
MAVEN=$(py maven)
KOTLIN=$(py kotlin)
GO=$(py go)

ARTIFACT=$(py artifact)
ARTIFACT_NAME=$(py artifactName)

VERACODE_API_ID=$(py veracodeApiId)
VERACODE_API_KEY=$(py veracodeApiKey)
SCA_TOKEN=$(py scaToken)
IAC_TOKEN=$(py iacToken)

DEBUG_LOG=$(py debug)

[[ -n "$VERACODE_API_ID" ]] && log_ok "veracodeApiId encontrado." || true
[[ -n "$VERACODE_API_KEY" ]] && log_ok "veracodeApiKey encontrado." || true

if [[ "$ENABLE_SCA" != "true" && "$ENABLE_US" != "true" && "$ENABLE_PS" != "true" && "$ENABLE_IAC" != "true" && "$ENABLE_AP" != "true" ]]; then
  fail "❌ Nenhuma análise foi habilitada. Ative pelo menos uma flag enableX."
fi

if [[ "$ENABLE_US" == "true" || "$ENABLE_PS" == "true" || "$ENABLE_IAC" == "true" ]]; then
  [[ -z "$VERACODE_API_ID" ]] && fail "❌ Erro: veracodeApiId não informado. Adicione via secrets.VERACODE_API_ID." || true
  [[ -z "$VERACODE_API_KEY" ]] && fail "❌ Erro: veracodeApiKey não informado. Adicione via secrets.VERACODE_API_KEY." || true
fi

if [[ "$ENABLE_SCA" == "true" ]]; then
  [[ -z "$SCA_TOKEN" ]] && fail "❌ Erro: scaToken não informado. Adicione via secrets.SRCCLR_API_TOKEN (mapeado para scaToken)." || true
fi

if [[ "$ENABLE_IAC" == "true" ]]; then
  if [[ -z "$IAC_TOKEN" && ( -z "$VERACODE_API_ID" || -z "$VERACODE_API_KEY" ) ]]; then
    fail "❌ Erro: credenciais para IaC ausentes. Informe iacToken ou veracodeApiId/veracodeApiKey."
  fi
fi

if [[ "$ENABLE_US" == "true" || "$ENABLE_PS" == "true" ]]; then
  if [[ "$ENABLE_AP" != "true" && "$ARTIFACT" != "true" && "$JAVA" != "true" && "$DOTNET" != "true" && "$GRADLE" != "true" && "$MAVEN" != "true" && "$KOTLIN" != "true" && "$GO" != "true" ]]; then
    fail "❌ É necessário ativar o Auto Packager, um build ou fornecer um artefato pronto."
  fi
fi

if [[ "$ARTIFACT" == "true" ]]; then
  [[ -z "$ARTIFACT_NAME" ]] && fail "❌ Erro: artifactName é obrigatório quando artifact=true." || true
fi

RUNNER_OS_NAME="${RUNNER_OS:-}"
if [[ "$ENABLE_AP" == "true" || "$ENABLE_IAC" == "true" ]]; then
  case "$RUNNER_OS_NAME" in
    Linux|macOS|Darwin|linux)
      : ;; # ok
    *)
      log_err "⚠️ Runner OS não suportado para instalação automática da Veracode CLI: '$RUNNER_OS_NAME'."
      log_err "   Recomende usar 'runs-on: ubuntu-latest' para enableAP/enableIAC."
      ;;
  esac
fi

log_ok "Nenhum erro encontrado. Continuando..."
