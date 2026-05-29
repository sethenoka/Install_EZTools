log() {
  printf '%s\n' "$*" >&2
}

colorize() {
  local color="$1"
  shift
  local reset=$'\e[0m'
  local code

  case "${color}" in
    green) code=$'\e[0;32m' ;;
    yellow) code=$'\e[0;33m' ;;
    red) code=$'\e[0;31m' ;;
    *) code="" ;;
  esac

  log "${code}$*${reset}"
}

success() {
  colorize green "$*"
}

warn() {
  colorize yellow "WARNING: $*"
}

completed_or_planned() {
  local completed_message="$1"
  local planned_message="$2"

  if [[ "${DRY_RUN}" == true ]]; then
    success "${planned_message}"
  else
    success "${completed_message}"
  fi
}

die() {
  colorize red "ERROR: $*"
  exit 1
}

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
