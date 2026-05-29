execute_cmd() {
  local use_sudo="$1"
  local description="$2"
  shift 2

  if [[ "${DRY_RUN}" == true ]]; then
    printf '[dry-run] %s:' "${description}" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    return 0
  fi

  log "${description}..."
  if [[ "${VERBOSE}" == true ]]; then
    if [[ "${use_sudo}" == true ]]; then
      sudo_cmd "$@"
    else
      "$@"
    fi
  else
    if [[ "${use_sudo}" == true ]]; then
      sudo_cmd "$@" >/dev/null
    else
      "$@" >/dev/null
    fi
  fi
}

run_cmd() {
  execute_cmd false "$@"
}

sudo_cmd() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_sudo_cmd() {
  execute_cmd true "$@"
}

require_not_root() {
  if [[ "${EUID}" -eq 0 && "${ALLOW_ROOT}" != true ]]; then
    die "Do not run this script with sudo/root. Run it as your user; it will ask for sudo only for system paths. Use --allow-root only if you intentionally want root-owned profile and .NET files."
  fi
}

# Keep platform checks explicit until non-apt package managers are implemented.
require_debian_ubuntu() {
  local os_id=""
  local os_like=""

  # shellcheck source=/dev/null
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    os_id="${ID:-}"
    os_like="${ID_LIKE:-}"
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    die "apt-get was not found. This installer currently supports Debian/Ubuntu only."
  fi

  case "${os_id,,} ${os_like,,}" in
    *debian*|*ubuntu*) ;;
    *) die "Unsupported OS '${os_id:-unknown}'. This installer currently supports Debian/Ubuntu only." ;;
  esac
}

require_commands() {
  if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    die "sudo is required for package installs and writes under ${INSTALL_ROOT} and ${WRAPPER_DIR}."
  fi
}

# Prefer the managed per-user install, but reuse a compatible system dotnet.
detect_existing_dotnet() {
  local path_dotnet

  if [[ -x "${DOTNET_INSTALL_ROOT}/dotnet" ]]; then
    DOTNET_ROOT="${DOTNET_INSTALL_ROOT}"
    DOTNET_BIN="${DOTNET_INSTALL_ROOT}/dotnet"
    return 0
  fi

  if path_dotnet="$(command -v dotnet 2>/dev/null)"; then
    DOTNET_BIN="${path_dotnet}"
    DOTNET_ROOT="$(dirname "${path_dotnet}")"
  fi
}

package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Install only missing packages so repeated runs stay quiet and predictable.
install_prereqs() {
  local packages=(ca-certificates wget unzip gnupg)
  local missing=()
  local package

  for package in "${packages[@]}"; do
    if ! package_installed "${package}"; then
      missing+=("${package}")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    success "Prerequisites already installed."
    return 0
  fi

  log "Missing prerequisites: ${missing[*]}"
  confirm "Install missing prerequisite packages?"
  run_sudo_cmd "Updating apt package index" apt-get update
  run_sudo_cmd "Installing prerequisites" env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
  completed_or_planned "Prerequisites installed." "Prerequisites would be installed."
}

download_file() {
  local url="$1"
  local output="$2"
  local quiet=(-q)

  if [[ "${VERBOSE}" == true ]]; then
    quiet=()
  fi

  run_cmd "Downloading ${url}" wget --https-only --tries=3 --timeout=30 --waitretry=2 "${quiet[@]}" -O "${output}" "${url}"
}

# Channels such as 9.0 can be checked precisely; named channels are treated as
# present when any dotnet binary exists because their resolved version changes.
dotnet_channel_installed() {
  local major_minor="$1"
  local escaped

  [[ -x "${DOTNET_BIN}" ]] || return 1

  if [[ ! "${major_minor}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    return 0
  fi

  escaped="${major_minor//./\\.}"
  if [[ "${DOTNET_KIND}" == "runtime" ]]; then
    "${DOTNET_BIN}" --list-runtimes 2>/dev/null | grep -Eq "^Microsoft\\.NETCore\\.App ${escaped}\\."
  else
    "${DOTNET_BIN}" --list-sdks 2>/dev/null | grep -Eq "^${escaped}\\."
  fi
}

# Microsoft publishes a detached signature for dotnet-install.sh, so verify the
# bootstrap script before executing it unless the caller opts out.
install_dotnet() {
  local script_path
  local sig_path
  local key_path
  local gpg_home
  local install_args=(--channel "${DOTNET_CHANNEL}" --install-dir "${DOTNET_INSTALL_ROOT}" --no-path)

  if [[ "${DOTNET_KIND}" == "runtime" ]]; then
    install_args+=(--runtime dotnet)
  fi

  if [[ "${FORCE}" != true ]] && dotnet_channel_installed "${DOTNET_CHANNEL}"; then
    success ".NET ${DOTNET_KIND} channel ${DOTNET_CHANNEL} already available at ${DOTNET_BIN}."
    return 0
  fi

  confirm "Install .NET ${DOTNET_KIND} channel ${DOTNET_CHANNEL} into ${DOTNET_INSTALL_ROOT}?"

  DOTNET_ROOT="${DOTNET_INSTALL_ROOT}"
  DOTNET_BIN="${DOTNET_INSTALL_ROOT}/dotnet"

  TMP_DIR="$(mktemp -d)"
  script_path="${TMP_DIR}/dotnet-install.sh"
  sig_path="${TMP_DIR}/dotnet-install.sig"
  key_path="${TMP_DIR}/dotnet-install.asc"
  gpg_home="${TMP_DIR}/gnupg"

  download_file "https://dot.net/v1/dotnet-install.sh" "${script_path}"

  if [[ "${VERIFY_DOTNET_SIGNATURE}" == true ]]; then
    download_file "https://dot.net/v1/dotnet-install.sig" "${sig_path}"
    download_file "https://dot.net/v1/dotnet-install.asc" "${key_path}"
    if [[ "${DRY_RUN}" != true ]]; then
      mkdir -m 700 "${gpg_home}"
      GNUPGHOME="${gpg_home}" gpg --import "${key_path}" >/dev/null 2>&1
      GNUPGHOME="${gpg_home}" gpg --verify "${sig_path}" "${script_path}" >/dev/null 2>&1
    else
      log "[dry-run] Verify dotnet-install.sh GPG signature"
    fi
  else
    warn "Skipping dotnet-install.sh signature verification."
  fi

  run_cmd "Installing .NET ${DOTNET_KIND}" bash "${script_path}" "${install_args[@]}"
  completed_or_planned \
    ".NET ${DOTNET_KIND} channel ${DOTNET_CHANNEL} installed." \
    ".NET ${DOTNET_KIND} channel ${DOTNET_CHANNEL} would be installed."
}

# Replace the managed block on every run instead of appending duplicate exports.
update_profile() {
  local begin="# >>> Install_EZTools >>>"
  local end="# <<< Install_EZTools <<<"
  local temp_profile

  if [[ "${UPDATE_PROFILE}" != true ]]; then
    return 0
  fi

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] Update ${PROFILE_FILE} with DOTNET_ROOT/PATH block"
    return 0
  fi

  mkdir -p "$(dirname "${PROFILE_FILE}")"
  touch "${PROFILE_FILE}"
  temp_profile="$(mktemp)"
  sed "/${begin}/,/${end}/d" "${PROFILE_FILE}" > "${temp_profile}"
  {
    printf '\n%s\n' "${begin}"
    if [[ "${DOTNET_BIN}" == "${DOTNET_INSTALL_ROOT}/dotnet" ]]; then
      printf 'export DOTNET_ROOT="%s"\n' "${DOTNET_ROOT}"
      printf "case \":\${PATH}:\" in *\":\${DOTNET_ROOT}:\"*) ;; *) export PATH=\"\${DOTNET_ROOT}:\${PATH}\" ;; esac\n"
    fi
    printf "case \":\${PATH}:\" in *\":%s:\"*) ;; *) export PATH=\"\${PATH}:%s\" ;; esac\n" "${WRAPPER_DIR}" "${WRAPPER_DIR}"
    printf '%s\n' "${end}"
  } >> "${temp_profile}"
  mv "${temp_profile}" "${PROFILE_FILE}"
  success "Updated ${PROFILE_FILE}."
}
