#!/usr/bin/env bash
# Explicação: Funções auxiliares para validar artefatos, detectar saídas de build e exportar outputs.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

shopt -s globstar 2>/dev/null || true

assert_artifact_exists() {
  local path="${1:-}"
  [[ -z "$path" ]] && fail "Erro interno: caminho do artefato não informado."
  if [[ ! -e "$path" ]];
  then
    fail "❌ Artefato '${path}' não encontrado."
  fi
  log_ok "Artefato encontrado: ${path}"
}

detect_default_artifact() {
  local found=""
  # Priority: fat jars / jars / wars / ears
  found=$(ls -1 **/*-all.jar **/*-with-dependencies.jar **/target/*.jar **/build/libs/*.jar 2>/dev/null | head -n1 || true)
  if [[ -z "$found" ]]; then found=$(ls -1 **/*.war **/*.ear 2>/dev/null | head -n1 || true); fi
  # .NET
  if [[ -z "$found" ]]; then found=$(ls -1 **/bin/**/Release/**/*.{dll,exe} 2>/dev/null | head -n1 || true); fi
  # Go
  if [[ -z "$found" ]]; then found=$(ls -1 **/bin/**/app **/dist/**/app **/*.so **/*.a 2>/dev/null | head -n1 || true); fi
  # Common zips/dist
  if [[ -z "$found" ]]; then found=$(ls -1 **/dist/**/*.zip **/build/**/*.zip 2>/dev/null | head -n1 || true); fi
  if [[ -n "$found" ]]; then echo "$found"; return 0; fi
  return 1
}

set_output() {
  local key="$1"; shift
  local val="$*"
  echo "${key}=${val}" >> "$GITHUB_OUTPUT"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    assert_artifact_exists)
      assert_artifact_exists "$@" ;;
    detect_default_artifact)
      detect_default_artifact "$@" ;;
    *)
      echo "helpers.sh: comando desconhecido: $cmd" >&2
      exit 1 ;;
  esac
fi
