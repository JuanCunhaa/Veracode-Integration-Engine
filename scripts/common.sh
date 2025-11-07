#!/usr/bin/env bash
# Explicação: Funções utilitárias de log e controle de execução usadas por toda a ação.
set -euo pipefail

emoji_info="ℹ️"
emoji_ok="✅"
emoji_err="❌"
emoji_gear="⚙️"
emoji_pkg="📦"
emoji_upl="📤"

log_info() { echo -e "${emoji_info} $*"; }
log_step() { echo -e "${emoji_gear} $*"; }
log_ok() { echo -e "${emoji_ok} $*"; }
log_err() { echo -e "${emoji_err} $*" 1>&2; }
fail() { log_err "$*"; exit 1; }

to_bool() {
  case "${1:-}" in
    true|True|TRUE|1|yes|on) echo "true";;
    *) echo "false";;
  esac
}

ci_debug() {
  [[ "${DEBUG_LOG:-false}" == "true" ]] && set -x || true
}
