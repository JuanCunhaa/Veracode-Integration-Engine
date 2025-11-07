#!/usr/bin/env bash
# Explicação: Executa o Pipeline Scan usando o JAR oficial e emite somente logs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

ci_debug

VID="${VERACODE_API_ID:-}"; VKEY="${VERACODE_API_KEY:-}"
[[ -z "$VID" ]] && fail "❌ Erro: veracodeApiId não informado. Adicione via secrets.VERACODE_API_ID."
[[ -z "$VKEY" ]] && fail "❌ Erro: veracodeApiKey não informado. Adicione via secrets.VERACODE_API_KEY."

ARTIFACT="${ARTIFACT_PATH:-}"
if [[ -z "$ARTIFACT" ]]; then
  if ARTIFACT=$(detect_default_artifact); then
    log_info "Artefato detectado automaticamente: $ARTIFACT"
  else
    fail "❌ Nenhum artefato encontrado para o Pipeline Scan."
  fi
fi

assert_artifact_exists "$ARTIFACT"

log_step "🚀 Executando Veracode Pipeline Scan..."

TMP="$RUNNER_TEMP"; [[ -z "${TMP:-}" ]] && TMP="/tmp"
DL_ZIP="$TMP/pipeline-scan.zip"
DL_DIR="$TMP/pipeline-scan"
JAR="$DL_DIR/pipeline-scan.jar"

rm -rf "$DL_DIR" "$DL_ZIP" || true
curl -sSL -o "$DL_ZIP" https://downloads.veracode.com/securityscan/pipeline-scan-LATEST.zip
mkdir -p "$DL_DIR"
unzip -q "$DL_ZIP" -d "$DL_DIR"

[[ -f "$JAR" ]] || fail "❌ Falha ao baixar o pipeline-scan.jar"

JAVA_OPTS=()
if [[ "${DEBUG_LOG:-false}" == "true" ]]; then
  JAVA_OPTS+=(--verbose)
fi

APPNAME="Github - ${GITHUB_REPOSITORY:-local}"

set +e
java -jar "$JAR" \
  -vid "$VID" -vkey "$VKEY" \
  -f "$ARTIFACT" \
  --project_name "$APPNAME" \
  --summary_display=true \
  --json_display=false \
  --json_output=false \
  --summary_output=false \
  "${JAVA_OPTS[@]}"
status=$?
set -e

# Livrar arquivos gerados por padrão, se existirem
rm -f results.json filtered_results.json results.txt || true

if [[ $status -ne 0 ]]; then
  fail "❌ Pipeline Scan finalizou com código $status. Veja o log acima."
fi

log_ok "Pipeline Scan concluído com sucesso."
