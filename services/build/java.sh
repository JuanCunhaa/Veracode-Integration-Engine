#!/usr/bin/env bash
# Explicação: Compila Java puro (ou executa comando custom), gera JAR e empacota um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build Java (puro) iniciado..."
ci_debug

BUILD_CMD="${JAVA_BUILD_CMD:-}"
SRC_DIR="${JAVA_SOURCE_DIR:-src/main/java}"
RES_DIR="${JAVA_RES_DIR:-src/main/resources}"
LIB_DIR="${JAVA_LIB_DIR:-lib}"
JAR_NAME="${JAVA_JAR_NAME:-app.jar}"
MAIN_CLASS="${JAVA_MAIN_CLASS:-}"
OUTPUT_DIR="${JAVA_OUTPUT_DIR:-dist/veracode-java}"
JAVAC_EXTRA="${JAVA_ADDITIONAL_JAVAC_ARGS:-}"
JAR_EXTRA="${JAVA_ADDITIONAL_JAR_ARGS:-}"

mkdir -p "$OUTPUT_DIR"

# If custom command provided, run it and package outputs
if [[ -n "$BUILD_CMD" ]]; then
  echo "Executando comando customizado: $BUILD_CMD"
  eval "$BUILD_CMD"
else
  # Attempt to compile and jar manually
  # Determine source dir if not found
  if [[ ! -d "$SRC_DIR" ]]; then
    if [[ -d "src/main/java" ]]; then SRC_DIR="src/main/java"; elif [[ -d "src" ]]; then SRC_DIR="src"; fi
  fi
  [[ -d "$SRC_DIR" ]] || fail "❌ Diretório de fontes Java não encontrado: $SRC_DIR"

  CLASSES_DIR="$OUTPUT_DIR/classes"
  rm -rf "$CLASSES_DIR" || true
  mkdir -p "$CLASSES_DIR"

  # Build classpath from external libs
  CP=""
  if [[ -d "$LIB_DIR" ]]; then
    mapfile -t JARS < <(ls -1 "$LIB_DIR"/*.jar 2>/dev/null || true)
    if [[ ${#JARS[@]} -gt 0 ]]; then
      CP=$(IFS=':'; echo "${JARS[*]}")
    fi
  fi

  # Collect sources
  TMP_SOURCES="${RUNNER_TEMP:-/tmp}/sources_java.txt"
  rm -f "$TMP_SOURCES" || true
  find "$SRC_DIR" -type f -name "*.java" > "$TMP_SOURCES"
  if [[ ! -s "$TMP_SOURCES" ]]; then
    fail "❌ Nenhum arquivo .java encontrado em $SRC_DIR"
  fi

  # Compile with symbols (-g)
  CMD=(javac -g -d "$CLASSES_DIR")
  [[ -n "$CP" ]] && CMD+=( -classpath "$CP" )
  if [[ -n "$JAVAC_EXTRA" ]]; then
    # shellcheck disable=SC2206
    extraArgs=( $JAVAC_EXTRA )
    CMD+=("${extraArgs[@]}")
  fi
  CMD+=( @"$TMP_SOURCES" )
  echo "Executando: ${CMD[*]}"
  "${CMD[@]}"

  # Prepare manifest if main class provided
  MANIFEST="${RUNNER_TEMP:-/tmp}/manifest.mf"
  echo "Manifest-Version: 1.0" > "$MANIFEST"
  if [[ -n "$MAIN_CLASS" ]]; then
    echo "Main-Class: $MAIN_CLASS" >> "$MANIFEST"
  fi

  # Create jar
  JAR_PATH="$OUTPUT_DIR/$JAR_NAME"
  rm -f "$JAR_PATH" || true
  JAR_CMD=(jar cfm "$JAR_PATH" "$MANIFEST")
  if [[ -d "$CLASSES_DIR" ]]; then
    JAR_CMD+=( -C "$CLASSES_DIR" . )
  fi
  if [[ -d "$RES_DIR" ]]; then
    JAR_CMD+=( -C "$RES_DIR" . )
  fi
  if [[ -n "$JAR_EXTRA" ]]; then
    # shellcheck disable=SC2206
    jarExtra=( $JAR_EXTRA )
    JAR_CMD+=("${jarExtra[@]}")
  fi
  echo "Executando: ${JAR_CMD[*]}"
  "${JAR_CMD[@]}"
fi

# Package for Veracode: include any jar/war/ear built + optional libs
log_step "Empacotando artefatos Java para Veracode..."
PKG_ZIP="$OUTPUT_DIR/veracode-java-package.zip"
rm -f "$PKG_ZIP" || true
STAGE="$OUTPUT_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE/artifacts" "$STAGE/lib"

found=false
while IFS= read -r -d '' f; do cp "$f" "$STAGE/artifacts/"; found=true; done < <(find "$OUTPUT_DIR" -maxdepth 2 -type f \( -name "*.jar" -o -name "*.war" -o -name "*.ear" \) -print0 2>/dev/null || true)
if [[ "$found" == "false" ]]; then
  # search project tree as fallback
  while IFS= read -r -d '' f; do cp "$f" "$STAGE/artifacts/"; found=true; done < <(find . -type f \( -name "*.jar" -o -name "*.war" -o -name "*.ear" \) -print0 2>/dev/null || true)
fi

if [[ -d "$LIB_DIR" ]]; then
  while IFS= read -r -d '' f; do cp "$f" "$STAGE/lib/"; done < <(find "$LIB_DIR" -type f -name "*.jar" -print0 2>/dev/null || true)
fi

if [[ "$found" == "false" ]]; then
  fail "❌ Nenhum artefato Java encontrado para empacotar. Verifique build e caminhos."
fi

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Pacote Java criado: $PKG_ZIP"
