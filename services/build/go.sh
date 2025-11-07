#!/usr/bin/env bash
# Explicação: Executa build de aplicações Go, valida binários e empacota um zip padrão para o Veracode.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/common.sh"
source "$SCRIPT_DIR/../../scripts/helpers.sh"

shopt -s globstar 2>/dev/null || true

log_step "${emoji_pkg} Build Go iniciado..."
ci_debug

# Read envs
BUILD_CMD="${GO_BUILD_CMD:-}"
MAIN_PATH="${GO_MAIN:-}"
GOOS_IN="${GO_OS:-}"
GOARCH_IN="${GO_ARCH:-}"
CGO="${GO_CGO:-0}"
LDFLAGS="${GO_LDFLAGS:-}"
TAGS="${GO_TAGS:-}"
OUTPUT_DIR="${GO_OUTPUT_DIR:-dist/veracode-go}"
BIN_NAME="${GO_BINARY_NAME:-}"
ADDL_ARGS="${GO_ADDITIONAL_ARGS:-}"
MOD_VENDOR="${GO_MOD_VENDOR:-false}"
DO_GENERATE="${GO_GENERATE:-false}"
USE_RACE="${GO_RACE:-false}"

mkdir -p "$OUTPUT_DIR/bin"

# Optional pre-steps
if [[ "$DO_GENERATE" == "true" ]]; then
  echo "go generate ./..."
  go generate ./...
fi

if [[ "$MOD_VENDOR" == "true" ]]; then
  echo "go mod vendor"
  go mod vendor
fi

# Set env for cross-compile if provided
if [[ -n "$GOOS_IN" ]]; then export GOOS="$GOOS_IN"; fi
if [[ -n "$GOARCH_IN" ]]; then export GOARCH="$GOARCH_IN"; fi
export CGO_ENABLED="$CGO"

# Function to run a single build
go_build_one() {
  local pkg="$1"
  local outName="$2"
  local outBin="$OUTPUT_DIR/bin/$outName"
  local args=(build -o "$outBin")
  [[ -n "$LDFLAGS" ]] && args+=(-ldflags "$LDFLAGS")
  [[ -n "$TAGS" ]] && args+=(-tags "$TAGS")
  [[ "$USE_RACE" == "true" ]] && args+=(-race)
  if [[ -n "$ADDL_ARGS" ]]; then
    # shellcheck disable=SC2206
    extra=( $ADDL_ARGS )
    args+=("${extra[@]}")
  fi
  args+=("$pkg")
  echo "Executando: go ${args[*]}"
  go "${args[@]}"
  if [[ -n "$GOOS_IN" && "$GOOS_IN" == "windows" && ! "$outBin" =~ \.exe$ ]]; then
    mv "$outBin" "$outBin.exe"
    outBin+=".exe"
  fi
  echo "$outBin"
}

declare -a built_bins

if [[ -n "$BUILD_CMD" ]]; then
  echo "Executando comando customizado: $BUILD_CMD"
  eval "$BUILD_CMD"
  # Tentar descobrir binários gerados no output
  mapfile -t built_bins < <(find "$OUTPUT_DIR" -maxdepth 3 -type f -perm -111 2>/dev/null || true)
else
  # Determine main packages to build
  declare -a mains
  if [[ -n "$MAIN_PATH" ]]; then
    mains=("$MAIN_PATH")
  else
    # Detect all 'main' packages in repo
    mapfile -t mains < <(go list -f '{{.Name}}|{{.ImportPath}}|{{.Dir}}' ./... 2>/dev/null | awk -F '|' '$1=="main"{print $2}')
    if [[ ${#mains[@]} -eq 0 ]]; then
      fail "❌ Nenhum package 'main' encontrado. Informe 'goMain' ou ajuste seu projeto."
    fi
  fi

  # Build each main package
  if [[ ${#mains[@]} -eq 1 ]]; then
    name="$BIN_NAME"
    if [[ -z "$name" ]]; then
      # derive name from dir
      dir="$(go list -f '{{.Dir}}' "${mains[0]}")"
      name="$(basename "$dir")"
      [[ -z "$name" ]] && name="app"
    fi
    binpath=$(go_build_one "${mains[0]}" "$name")
    built_bins+=("$binpath")
  else
    for imp in "${mains[@]}"; do
      dir="$(go list -f '{{.Dir}}' "$imp")"
      name="$(basename "$dir")"
      [[ -z "$name" ]] && name="app"
      binpath=$(go_build_one "$imp" "$name")
      built_bins+=("$binpath")
    done
  fi
fi

# Validate binaries exist
if [[ ${#built_bins[@]} -eq 0 ]]; then
  # Try to find executables inside OUTPUT_DIR/bin
  mapfile -t built_bins < <(find "$OUTPUT_DIR/bin" -type f -perm -111 2>/dev/null || true)
fi

if [[ ${#built_bins[@]} -eq 0 ]]; then
  fail "❌ Nenhum binário Go encontrado após o build. Verifique os parâmetros e o projeto."
fi

log_ok "Build Go finalizado. Binários: ${built_bins[*]}"

# Package binaries and relevant metadata
log_step "Empacotando artefatos Go para Veracode..."
PKG_DIR="$OUTPUT_DIR"
PKG_ZIP="$PKG_DIR/veracode-go-package.zip"
rm -f "$PKG_ZIP" || true
STAGE="$PKG_DIR/_stage"
rm -rf "$STAGE" || true
mkdir -p "$STAGE/bin"

# Copy binaries
for b in "${built_bins[@]}"; do
  cp "$b" "$STAGE/bin/"
done

# Include module files and common configs
for f in go.mod go.sum; do [[ -f "$f" ]] && cp "$f" "$STAGE/" || true; done
find . -maxdepth 2 -type f \( -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.conf" -o -name "*.ini" -o -name ".env*" \) -print0 | xargs -0 -I {} sh -c 'mkdir -p "$STAGE/config"; cp "{}" "$STAGE/config/"' || true

(cd "$STAGE" && zip -r -q "$(basename "$PKG_ZIP")" .)
mv "$STAGE/$(basename "$PKG_ZIP")" "$PKG_ZIP"
rm -rf "$STAGE" || true

assert_artifact_exists "$PKG_ZIP"
log_ok "Pacote Go criado: $PKG_ZIP"
