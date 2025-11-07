#!/usr/bin/env bash
# Explicação: Realiza Upload & Scan via Java API Wrapper e resolve o upload_guid de forma confiável.
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
  elif [[ -f "veracode_package.zip" ]]; then
    ARTIFACT="veracode_package.zip"
  else
    fail "❌ Nenhum artefato encontrado para Upload & Scan."
  fi
fi

assert_artifact_exists "$ARTIFACT"

APPNAME="Github - ${GITHUB_REPOSITORY:-local}"
VERSION="Scan from Github job: ${GITHUB_RUN_ID:-local}-${GITHUB_RUN_NUMBER:-0}-${GITHUB_RUN_ATTEMPT:-0}"

log_step "☁️ Upload & Scan (Plataforma)"
log_info "📤 Upload iniciado..."

# Baixa wrapper Java mais recente
JAVA_META=$(curl -sS https://repo1.maven.org/maven2/com/veracode/vosp/api/wrappers/vosp-api-wrappers-java/maven-metadata.xml)
JAVA_WRAPPER_VERSION=$(echo "$JAVA_META" | grep -m1 '<latest>' | sed -E 's/.*<latest>([^<]+)<\/latest>.*/\1/')
WRAPPER_JAR="$RUNNER_TEMP/VeracodeJavaAPI.jar"
curl -sS -L -o "$WRAPPER_JAR" "https://repo1.maven.org/maven2/com/veracode/vosp/api/wrappers/vosp-api-wrappers-java/${JAVA_WRAPPER_VERSION}/vosp-api-wrappers-java-${JAVA_WRAPPER_VERSION}.jar"
[[ -s "$WRAPPER_JAR" ]] || fail "❌ Não foi possível baixar o Java API Wrapper da Veracode."

set +e
java -jar "$WRAPPER_JAR" \
  -action "uploadandscan" \
  -appname "$APPNAME" \
  -createprofile "true" \
  -filepath "$ARTIFACT" \
  -version "$VERSION" \
  -vid "$VID" -vkey "$VKEY"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  fail "❌ Falha no Upload & Scan. Verifique logs acima."
fi

# Resolver o upload_guid (build_id) via getbuildlist
log_info "🔎 Resolvendo upload_guid na plataforma Veracode..."
ATTEMPTS=6
GUID=""
for i in $(seq 1 $ATTEMPTS); do
  XML=$(java -jar "$WRAPPER_JAR" -action getbuildlist -appname "$APPNAME" -vid "$VID" -vkey "$VKEY" || true)
  if [[ -n "$XML" ]]; then
    GUID=$(python3 - "$VERSION" <<'PY'
import sys, xml.etree.ElementTree as ET
version=sys.argv[1]
data=sys.stdin.read()
try:
    root=ET.fromstring(data)
    for b in root.iter('build'):
        if b.attrib.get('version')==version:
            print(b.attrib.get('build_id',''))
            sys.exit(0)
except Exception:
    pass
print('')
PY
)
  fi
  if [[ -n "$GUID" ]]; then break; fi
  echo "⏳ Aguardando build aparecer (tentativa $i/$ATTEMPTS)..."
  sleep 10
done

if [[ -z "$GUID" ]]; then
  fail "❌ Não foi possível resolver o upload_guid neste momento. Tente consultar na plataforma usando a versão: '$VERSION'"
fi

echo "🔗 upload_guid: ${GUID}"
[[ -n "${GITHUB_OUTPUT:-}" ]] && echo "upload_guid=${GUID}" >> "$GITHUB_OUTPUT" || true
log_ok "✅ Scan enviado para a plataforma Veracode."
