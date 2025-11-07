#!/usr/bin/env bash
# Explicação: Executa build Maven e empacota artefatos em um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build Maven iniciado..."
ci_debug

ROOT_DIR="$PWD"
CMD="${MVN_CMD:-}"
WRAPPER="${MVN_WRAPPER:-./mvnw}"
GOALS="${MVN_GOALS:--B -DskipTests package}"
PROJECT_DIR="${MVN_PROJECT_DIR:-.}"
OPTIONS="${MVN_OPTIONS:---no-transfer-progress}"
OUTPUT_DIR_REL="${MVN_OUTPUT_DIR:-dist/veracode-maven}"
OUTPUT_DIR="$ROOT_DIR/$OUTPUT_DIR_REL"

mkdir -p "$OUTPUT_DIR"

if [[ -n "$PROJECT_DIR" && "$PROJECT_DIR" != "." ]]; then
  if [[ -d "$PROJECT_DIR" ]]; then
    echo "Entrando no diretório do projeto Maven: $PROJECT_DIR"
    cd "$PROJECT_DIR"
  else
    fail "❌ mavenProjectDir não encontrado: $PROJECT_DIR"
  fi
fi

if [[ -n "$CMD" ]]; then
  echo "Executando comando customizado: $CMD"
  eval "$CMD"
else
  if [[ -x "$WRAPPER" ]]; then
    echo "Executando wrapper: $WRAPPER $GOALS $OPTIONS"
    "$WRAPPER" $GOALS $OPTIONS
  else
    echo "Wrapper não encontrado/executável ($WRAPPER). Tentando 'mvn' no PATH."
    mvn $GOALS $OPTIONS
  fi
fi

# Empacotar JAR/WAR/EAR produzidos (multi-módulo incluído)
log_step "Empacotando artefatos Maven para Veracode..."

PKG_ZIP="$OUTPUT_DIR/veracode-maven-package.zip"
rm -f "$PKG_ZIP" || true
STAGE="$OUTPUT_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE/artifacts" "$STAGE/poms" "$STAGE/lib"

found_any=false
while IFS= read -r -d '' f; do
  cp "$f" "$STAGE/artifacts/"
  found_any=true
done < <(find . -type f \( -path "*/target/*.jar" -o -path "*/target/*.war" -o -path "*/target/*.ear" \) -print0 2>/dev/null || true)

# Incluir dependências copiadas por plugins comuns (dependency:copy-dependencies ou libs)
while IFS= read -r -d '' f; do
  cp "$f" "$STAGE/lib/"
  found_any=true
done < <(find . -type f \( -path "*/target/dependency/*.jar" -o -path "*/target/libs/*.jar" \) -print0 2>/dev/null || true)

# POMs (úteis para contexto), não obrigatórios
while IFS= read -r -d '' f; do
  rel="${f#./}"
  dest="$STAGE/poms/${rel%/*}"
  mkdir -p "$dest"
  cp "$f" "$dest/"
done < <(find . -type f -name "pom.xml" -print0 2>/dev/null || true)

if [[ "$found_any" == "false" ]]; then
  fail "❌ Nenhum artefato Maven encontrado após o build. Verifique goals/comando e caminhos de saída."
fi

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Pacote Maven criado: $PKG_ZIP"
