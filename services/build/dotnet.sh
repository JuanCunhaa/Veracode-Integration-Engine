#!/usr/bin/env bash
# Explicação: Executa build e publish .NET, inclui símbolos e empacota um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build .NET iniciado..."
ci_debug

# Read envs from composite inputs
BUILD_CMD="${DOTNET_BUILD_CMD:-}"
PROJECT_PATH="${DOTNET_PROJECT:-}"
SOLUTION_PATH="${DOTNET_SOLUTION:-}"
CONFIGURATION="${DOTNET_CONFIGURATION:-Release}"
RID="${DOTNET_RID:-}"
SELF_CONTAINED="${DOTNET_SELF_CONTAINED:-false}"
SINGLE_FILE="${DOTNET_SINGLE_FILE:-false}"
INCLUDE_SYMBOLS="${DOTNET_INCLUDE_SYMBOLS:-true}"
OUTPUT_DIR="${DOTNET_OUTPUT_DIR:-dist/veracode-dotnet}"
ADDL_ARGS="${DOTNET_ADDITIONAL_ARGS:-}"
DO_RESTORE="${DOTNET_RESTORE:-false}"
RESTORE_CMD="${DOTNET_RESTORE_CMD:-dotnet restore}"
NUGET_CFG="${NUGET_CONFIG_PATH:-}"
NUGET_SRC="${NUGET_SOURCE:-}"
NUGET_USER="${NUGET_USERNAME:-}"
NUGET_PASS="${NUGET_PASSWORD:-}"

mkdir -p "$OUTPUT_DIR"

dotnet_publish_project() {
  local csproj="$1"
  local cmd=(dotnet publish "$csproj" -c "$CONFIGURATION")
  [[ -n "$RID" ]] && cmd+=(--runtime "$RID")
  if [[ "${SELF_CONTAINED}" == "true" ]]; then cmd+=(--self-contained true); else cmd+=(--self-contained false); fi
  if [[ "${SINGLE_FILE}" == "true" ]]; then cmd+=(-p:PublishSingleFile=true); fi
  if [[ -n "$ADDL_ARGS" ]]; then
    # shellcheck disable=SC2206
    extra_args=( $ADDL_ARGS )
    cmd+=("${extra_args[@]}")
  fi
  echo "Executando: ${cmd[*]}"
  "${cmd[@]}"
}

# Discover project if not provided
if [[ -z "$PROJECT_PATH" && -z "$SOLUTION_PATH" && -z "$BUILD_CMD" ]]; then
  mapfile -t CSPROJS < <(ls -1 **/*.csproj 2>/dev/null || true)
  if [[ ${#CSPROJS[@]} -eq 0 ]]; then
    fail "❌ Nenhum .csproj encontrado. Informe 'dotnetProject' ou 'dotnetSolution' ou 'dotnetBuildCmd'."
  elif [[ ${#CSPROJS[@]} -gt 1 ]]; then
    fail "❌ Mais de um .csproj encontrado. Informe 'dotnetProject' explicitamente."
  else
    PROJECT_PATH="${CSPROJS[0]}"
    log_info "Projeto detectado: ${PROJECT_PATH}"
  fi
fi

# If both solution and project are set, prefer project with a note
if [[ -n "$PROJECT_PATH" && -n "$SOLUTION_PATH" ]]; then
  log_info "ℹ️ 'dotnetProject' e 'dotnetSolution' informados; priorizando o projeto: $PROJECT_PATH"
  SOLUTION_PATH=""
fi

# Restore step (optional)
run_restore() {
  local target="$1"
  # Prefer provided nuget.config
  if [[ -n "$NUGET_CFG" && -f "$NUGET_CFG" ]]; then
    echo "dotnet restore $target --configfile <supplied>"
    dotnet restore "$target" --configfile "$NUGET_CFG"
    return
  fi
  # Generate temporary NuGet.config if source provided
  if [[ -n "$NUGET_SRC" ]]; then
    local TMP_CFG="${RUNNER_TEMP:-/tmp}/nuget.config"
    mkdir -p "${RUNNER_TEMP:-/tmp}"
    {
      echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
      echo "<configuration>"
      echo "  <packageSources>"
      echo "    <add key=\"custom\" value=\"$NUGET_SRC\" />"
      echo "  </packageSources>"
      if [[ -n "$NUGET_USER" && -n "$NUGET_PASS" ]]; then
        echo "  <packageSourceCredentials>"
        echo "    <custom>"
        echo "      <add key=\"Username\" value=\"$NUGET_USER\" />"
        echo "      <add key=\"ClearTextPassword\" value=\"$NUGET_PASS\" />"
        echo "    </custom>"
        echo "  </packageSourceCredentials>"
      fi
      echo "</configuration>"
    } > "$TMP_CFG"
    echo "dotnet restore $target --configfile <temp-config>"
    dotnet restore "$target" --configfile "$TMP_CFG"
    rm -f "$TMP_CFG" || true
    return
  fi
  # Fallback: basic restore
  echo "$RESTORE_CMD $target"
  $RESTORE_CMD "$target"
}

if [[ "$DO_RESTORE" == "true" ]]; then
  if [[ -n "$SOLUTION_PATH" ]]; then
    run_restore "$SOLUTION_PATH"
  elif [[ -n "$PROJECT_PATH" ]]; then
    run_restore "$PROJECT_PATH"
  else
    # If user provided custom build cmd but asked for restore, run generic restore
    run_restore "."
  fi
fi

if [[ -n "$BUILD_CMD" ]]; then
  echo "Executando comando customizado: $BUILD_CMD"
  eval "$BUILD_CMD"
else
  if [[ -n "$PROJECT_PATH" ]]; then
    dotnet_publish_project "$PROJECT_PATH"
  elif [[ -n "$SOLUTION_PATH" ]]; then
    echo "Compilando solution: $SOLUTION_PATH"
    dotnet build "$SOLUTION_PATH" -c "$CONFIGURATION"
    # Publicar todos os csproj encontrados (best-effort)
    mapfile -t ALL_CSPROJS < <(ls -1 **/*.csproj 2>/dev/null || true)
    for p in "${ALL_CSPROJS[@]}"; do
      dotnet_publish_project "$p" || true
    done
  else
    fail "❌ Parâmetros insuficientes para build .NET. Informe 'dotnetProject' ou 'dotnetSolution' ou 'dotnetBuildCmd'."
  fi
fi

# Packaging: prefer publish directories, else bin/<configuration>
log_step "Empacotando artefatos .NET para Veracode..."

PKG_DIR="$OUTPUT_DIR"
PKG_ZIP="$PKG_DIR/veracode-dotnet-package.zip"
rm -f "$PKG_ZIP" || true
mkdir -p "$PKG_DIR"

mapfile -t PUB_DIRS < <(ls -d **/bin/**/publish 2>/dev/null || true)
if [[ ${#PUB_DIRS[@]} -eq 0 ]]; then
  mapfile -t PUB_DIRS < <(ls -d **/bin/**/"$CONFIGURATION" 2>/dev/null || true)
fi

# Fallback: procurar diretórios que contenham arquivos característicos de publish
if [[ ${#PUB_DIRS[@]} -eq 0 ]]; then
  mapfile -t PUB_DIRS < <(find . -type f \( -name "*.deps.json" -o -name "*.runtimeconfig.json" \) -printf '%h\n' 2>/dev/null | sort -u)
fi

if [[ ${#PUB_DIRS[@]} -eq 0 ]]; then
  fail "❌ Nenhum artefato publicável encontrado após o build/publish. Verifique o projeto e parâmetros."
fi

STAGE="$PKG_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE"

copy_filtered() {
  local base="$1"
  local target="$2"
  find "$base" -type f \
    \( -name "*.dll" -o -name "*.exe" -o -name "*.json" -o -name "*.config" -o -name "*.deps.json" -o -name "*.runtimeconfig.json" -o -name "*.pdb" -o -name "*.so" -o -name "*.dylib" -o -name "*.a" \) \
    -print0 | while IFS= read -r -d '' f; do
      if [[ "$INCLUDE_SYMBOLS" != "true" && "$f" == *.pdb ]]; then continue; fi
      rel="${f#$base/}"
      mkdir -p "$target/$(dirname "$rel")"
      cp "$f" "$target/$rel"
    done
}

for d in "${PUB_DIRS[@]}"; do
  projname="$(basename "$(dirname "$d")")"
  dest="$STAGE/$projname"
  mkdir -p "$dest"
  copy_filtered "$d" "$dest"
done

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Build finalizado com sucesso. Artefato gerado: $PKG_ZIP"
