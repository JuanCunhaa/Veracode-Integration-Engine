#!/usr/bin/env bash
# Explicação: Executa build Kotlin (via Gradle) e empacota artefatos em um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build Kotlin iniciado..."
ci_debug

ROOT_DIR="$PWD"
WRAPPER="${KOTLIN_WRAPPER:-./gradlew}"
TASKS="${KOTLIN_TASKS:-assemble -x test}"
CMD="${KOTLIN_CMD:-}"
PROJECT_DIR="${KOTLIN_PROJECT_DIR:-.}"
OPTIONS="${KOTLIN_OPTIONS:---no-daemon}"
INCLUDE_DISTS="${KOTLIN_INCLUDE_DISTS:-true}"
OUTPUT_DIR_REL="${KOTLIN_OUTPUT_DIR:-dist/veracode-kotlin}"
OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR_REL"

mkdir -p "$OUTPUT_DIR"

if [[ -n "$PROJECT_DIR" && "$PROJECT_DIR" != "." ]]; then
  if [[ -d "$PROJECT_DIR" ]]; then
    echo "Entrando no diretório do projeto Kotlin: $PROJECT_DIR"
    cd "$PROJECT_DIR"
  else
    fail "❌ kotlinProjectDir não encontrado: $PROJECT_DIR"
  fi
fi

# Escolher comando de build
if [[ -n "$CMD" ]]; then
  echo "Executando comando customizado: $CMD"
  eval "$CMD"
else
  # Gradle build para Kotlin
  if [[ -x "$WRAPPER" ]]; then
    echo "Executando wrapper: $WRAPPER $TASKS $OPTIONS"
    "$WRAPPER" $TASKS $OPTIONS
  else
    echo "Wrapper não encontrado/executável ($WRAPPER). Tentando 'gradle' no PATH."
    gradle $TASKS $OPTIONS
  fi
fi

# Coletar artefatos e empacotar (JAR/WAR/EAR e dist zips)
log_step "Empacotando artefatos Kotlin para Veracode..."

PKG_ZIP="$OUTPUT_DIR/veracode-kotlin-package.zip"
rm -f "$PKG_ZIP" || true
STAGE="$OUTPUT_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE/artifacts"

found_any=false
while IFS= read -r -d '' f; do
  cp "$f" "$STAGE/artifacts/"
  found_any=true
done < <(find . -type f \( -path "*/build/libs/*.jar" -o -path "*/build/libs/*.war" -o -path "*/build/libs/*.ear" \) -print0 2>/dev/null || true)

if [[ "$INCLUDE_DISTS" == "true" ]]; then
  while IFS= read -r -d '' f; do
    cp "$f" "$STAGE/artifacts/"
    found_any=true
  done < <(find . -type f -path "*/build/distributions/*.zip" -print0 2>/dev/null || true)
fi

if [[ "$found_any" == "false" ]]; then
  # fallback: quaisquers jar/war/ear no repositório
  while IFS= read -r -d '' f; do
    cp "$f" "$STAGE/artifacts/"
    found_any=true
  done < <(find . -type f \( -name "*.jar" -o -name "*.war" -o -name "*.ear" \) -print0 2>/dev/null || true)
fi

if [[ "$found_any" == "false" ]]; then
  fail "❌ Nenhum artefato Kotlin encontrado após o build. Verifique tasks/comando e caminhos de saída."
fi

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Pacote Kotlin criado: $PKG_ZIP"
