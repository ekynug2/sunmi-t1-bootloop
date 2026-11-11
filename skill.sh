#!/usr/bin/env bash
# =============================================================================
# skill.sh — Installer untuk Skill "Perbaikan Bootloop / Restart Berulang Sunmi T1"
# Skill ID: sunmi-t1-bootloop-fixer v1.0.0
# =============================================================================
set -euo pipefail

SKILL_NAME="sunmi-t1-bootloop-skill"
SKILL_VERSION="1.0.0"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

usage() {
  cat <<EOF
Usage: $0 [TARGET_DIR]

Install skill Sunmi T1 Bootloop Fixer ke direktori tujuan AI agent.

Arguments:
  TARGET_DIR   Direktori tujuan (default: ./skills/${SKILL_NAME})

Examples:
  $0
  $0 ~/my-ai-agent/skills/sunmi-bootloop
  $0 /opt/ai-agent/skills/

Files yang akan disalin:
  - skill.json              Manifest skill
  - skill-prompt.md         System prompt / instruksi agent
  - PROSEDUR-BOOTLOOP-SUNMI-T1.md   Basis pengetahuan lengkap
  - README-install.md       Panduan instalasi
EOF
}

# -----------------------------------------------------------------------------
# Validasi file sumber ada
# -----------------------------------------------------------------------------
validate_source() {
  local missing=0
  for f in skill.json skill-prompt.md PROSEDUR-BOOTLOOP-SUNMI-T1.md README-install.md; do
    if [[ ! -f "${SRC_DIR}/${f}" ]]; then
      log_error "File sumber tidak ditemukan: ${SRC_DIR}/${f}"
      missing=1
    fi
  done
  if [[ ${missing} -ne 0 ]]; then
    log_error "Pastikan menjalankan script dari dalam folder ${SKILL_NAME}/"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
# Validasi JSON (opsional, jika python3 atau jq tersedia)
# -----------------------------------------------------------------------------
validate_json() {
  local json_file="${SRC_DIR}/skill.json"
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import json,sys; json.load(open('${json_file}'))" 2>/dev/null; then
      log_ok "skill.json valid (JSON)"
    else
      log_warn "skill.json tidak valid sebagai JSON — periksa kembali sintaks"
    fi
  elif command -v jq >/dev/null 2>&1; then
    if jq empty "${json_file}" 2>/dev/null; then
      log_ok "skill.json valid (JSON)"
    else
      log_warn "skill.json tidak valid sebagai JSON — periksa kembali sintaks"
    fi
  else
    log_info "Melewati validasi JSON (python3/jq tidak tersedia)"
  fi
}

# -----------------------------------------------------------------------------
# Salin ke target
# -----------------------------------------------------------------------------
install_skill() {
  local target_dir="$1"
  local dest="${target_dir}/${SKILL_NAME}"

  if [[ -d "${dest}" ]]; then
    log_warn "Direktori tujuan sudah ada: ${dest}"
    read -p "Overwrite? (y/N): " -r
    if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
      log_info "Instalasi dibatalkan."
      exit 0
    fi
    rm -rf "${dest}"
  fi

  mkdir -p "${target_dir}"
  cp -r "${SRC_DIR}" "${dest}"
  log_ok "Skill disalin ke: ${dest}"

  # Pastikan skill.sh executable di tujuan
  chmod +x "${dest}/skill.sh" 2>/dev/null || true

  echo ""
  log_ok "Instalasi selesai! Versi: ${SKILL_VERSION}"
  echo ""
  echo "Langkah selanjutnya:"
  echo "  1. Registrasi ${dest}/skill.json ke registry skill AI agent (jika didukung)."
  echo "  2. Masukkan isi ${dest}/skill-prompt.md sebagai system prompt tambahan."
  echo "  3. Pastikan ${dest}/PROSEDUR-BOOTLOOP-SUNMI-T1.md tetap ada bersama skill."
  echo ""
  echo "Lihat juga: ${dest}/README-install.md"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
  fi

  local target_dir="${1:-./skills/${SKILL_NAME}}"

  log_info "Memulai instalasi skill ${SKILL_NAME} v${SKILL_VERSION}"
  log_info "Sumber: ${SRC_DIR}"
  echo ""

  validate_source
  validate_json
  install_skill "${target_dir}"
}

main "$@"
