#!/usr/bin/env bash
# Explicação: Executa build Gradle e empacota os artefatos gerados em um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build Gradle iniciado..."
ci_debug

ROOT_DIR="$PWD"
WRAPPER="${GRADLE_WRAPPER:-./gradlew}"
TASKS="${GRADLE_TASKS:-assemble -x test}"
CMD="${GRADLE_CMD:-}"
PROJECT_DIR="${GRADLE_PROJECT_DIR:-.}"
OPTIONS="${GRADLE_OPTIONS:- --no-daemon}"
INCLUDE_DISTS="${GRADLE_INCLUDE_DISTS:-true}"
OUTPUT_DIR_REL="${GRADLE_OUTPUT_DIR:-dist/veracode-gradle}"
OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR_REL"

mkdir -p "$OUTPUT_DIR"

if [[ -n "$PROJECT_DIR" && "$PROJECT_DIR" != "." ]]; then
  if [[ -d "$PROJECT_DIR" ]]; then
    echo "Entrando no diretório do projeto Gradle: $PROJECT_DIR"
    cd "$PROJECT_DIR"
  else
    fail "❌ gradleProjectDir não encontrado: $PROJECT_DIR"
  fi
fi

# Escolher comando de build
if [[ -n "$CMD" ]]; then
  echo "Executando comando customizado: $CMD"
  eval "$CMD"
else
  if [[ -x "$WRAPPER" ]]; then
    echo "Executando wrapper: $WRAPPER $TASKS $OPTIONS"
    "$WRAPPER" $TASKS $OPTIONS
  else
    echo "Wrapper não encontrado/executável ($WRAPPER). Tentando 'gradle' no PATH."
    gradle $TASKS $OPTIONS
  fi
fi

# Coletar artefatos e empacotar
log_step "Empacotando artefatos Gradle para Veracode..."

PKG_ZIP="$OUTPUT_DIR/veracode-gradle-package.zip"
rm -f "$PKG_ZIP" || true
STAGE="$OUTPUT_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE/artifacts"

# Prefer build/libs jar/war/ear
found_any=false
while IFS= read -r -d '' f; do
  cp "$f" "$STAGE/artifacts/"
  found_any=true
done < <(find . -type f \( -path "*/build/libs/*.jar" -o -path "*/build/libs/*.war" -o -path "*/build/libs/*.ear" \) -print0 2>/dev/null || true)

# Optionally include distributions
if [[ "$INCLUDE_DISTS" == "true" ]]; then
  while IFS= read -r -d '' f; do
    cp "$f" "$STAGE/artifacts/"
    found_any=true
  done < <(find . -type f -path "*/build/distributions/*.zip" -print0 2>/dev/null || true)
fi

if [[ "$found_any" == "false" ]]; then
  # fallback: qualquer jar/war/ear na árvore
  while IFS= read -r -d '' f; do
    cp "$f" "$STAGE/artifacts/"
    found_any=true
  done < <(find . -type f \( -name "*.jar" -o -name "*.war" -o -name "*.ear" \) -print0 2>/dev/null || true)
fi

if [[ "$found_any" == "false" ]]; then
  fail "❌ Nenhum artefato Gradle encontrado após o build. Verifique tasks/comando e caminhos de saída."
fi

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Pacote Gradle criado: $PKG_ZIP"
