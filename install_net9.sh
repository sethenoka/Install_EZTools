#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"

# Defaults track Eric Zimmerman's current net9 Linux download layout.
DOTNET_CHANNEL="9.0"
DOTNET_KIND="runtime"
INSTALL_ROOT="/opt/zimmermantools/net9"
PROFILE_FILE="${HOME}/.bashrc"
UPDATE_PROFILE=true
ASSUME_YES=false
DRY_RUN=false
FORCE=false
VERBOSE=false
ALLOW_ROOT=false
VERIFY_DOTNET_SIGNATURE=true
SELECTED_TOOLS="all"
WRAPPER_DIR="/usr/local/bin"
DOTNET_INSTALL_ROOT="${HOME}/.dotnet"
DOTNET_ROOT="${DOTNET_INSTALL_ROOT}"
DOTNET_BIN="${DOTNET_INSTALL_ROOT}/dotnet"
TMP_DIR=""

# Tool manifest schema:
# key|display name|zip URL|extract destination under INSTALL_ROOT|DLL path under destination|optional sha256
TOOL_MANIFEST=(
  "amcacheparser|AmcacheParser|https://download.ericzimmermanstools.com/net9/AmcacheParser.zip|AmcacheParser|AmcacheParser.dll|"
  "appcompatcacheparser|AppCompatCacheParser|https://download.ericzimmermanstools.com/net9/AppCompatCacheParser.zip|AppCompatCacheParser|AppCompatCacheParser.dll|"
  "bstrings|bstrings|https://download.ericzimmermanstools.com/net9/bstrings.zip|bstrings|bstrings.dll|"
  "evtxecmd|EvtxECmd|https://download.ericzimmermanstools.com/net9/EvtxECmd.zip|.|EvtxeCmd/EvtxECmd.dll|"
  "iisgeolocate|iisGeolocate|https://download.ericzimmermanstools.com/net9/iisGeolocate.zip|.|iisGeolocate/iisGeolocate.dll|"
  "jlecmd|JLECmd|https://download.ericzimmermanstools.com/net9/JLECmd.zip|JLECmd|JLECmd.dll|"
  "lecmd|LECmd|https://download.ericzimmermanstools.com/net9/LECmd.zip|LECmd|LECmd.dll|"
  "mftecmd|MFTECmd|https://download.ericzimmermanstools.com/net9/MFTECmd.zip|MFTEcmd|MFTECmd.dll|"
  "pecmd|PECmd|https://download.ericzimmermanstools.com/net9/PECmd.zip|PECmd|PECmd.dll|"
  "rbcmd|RBCmd|https://download.ericzimmermanstools.com/net9/RBCmd.zip|RBCmd|RBCmd.dll|"
  "recentfilecacheparser|RecentFileCacheParser|https://download.ericzimmermanstools.com/net9/RecentFileCacheParser.zip|RecentFileCacheParser|RecentFileCacheParser.dll|"
  "recmd|RECmd|https://download.ericzimmermanstools.com/net9/RECmd.zip|.|RECmd/RECmd.dll|"
  "rla|RLA|https://download.ericzimmermanstools.com/net9/rla.zip|rla|rla.dll|"
  "sbecmd|SBECmd|https://download.ericzimmermanstools.com/net9/SBECmd.zip|SBECmd|SBECmd.dll|"
  "sqlecmd|SQLECmd|https://download.ericzimmermanstools.com/net9/SQLECmd.zip|.|SQLECmd/SQLECmd.dll|"
  "srumecmd|SrumECmd|https://download.ericzimmermanstools.com/net9/SrumECmd.zip|SrumECmd|SrumECmd.dll|"
  "sumecmd|SumECmd|https://download.ericzimmermanstools.com/net9/SumECmd.zip|SumECmd|SumECmd.dll|"
  "vscmount|VSCMount|https://download.ericzimmermanstools.com/net9/VSCMount.zip|VSCMount|VSCMount.dll|"
  "wxtcmd|WxTCmd|https://download.ericzimmermanstools.com/net9/WxTCmd.zip|WxTCmd|WxTCmd.dll|"
)

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [options]

Install Eric Zimmerman's .NET 9 CLI tools on Debian/Ubuntu systems.

Options:
  -t, --tools LIST          Comma-separated tools to install, or all
                            Default: all
  -d, --dest DIR            Root directory for EZ Tools. Default: ${INSTALL_ROOT}
  -c, --dotnet-channel CHANNEL
                            .NET channel passed to dotnet-install.sh. Default: ${DOTNET_CHANNEL}
  -k, --dotnet-kind KIND    Install "sdk" or "runtime". Default: ${DOTNET_KIND}
  -r, --runtime-only        Alias for --dotnet-kind runtime
  -s, --sdk                 Alias for --dotnet-kind sdk
  -p, --profile FILE        Shell profile to update. Default: ${PROFILE_FILE}
  -n, --no-profile          Do not update a shell profile
  -w, --wrapper-dir DIR     Directory for command wrappers. Default: ${WRAPPER_DIR}
  -f, --force               Reinstall .NET/tools even if the requested files are present
  -y, --yes                 Do not prompt for confirmation
  -D, --dry-run             Print planned actions without changing the system
  -v, --verbose             Show command output where practical
  --skip-dotnet-signature-check
                            Download dotnet-install.sh without GPG signature verification
  --allow-root              Allow running the whole script as root
  -h, --help                Show this help

Notes:
  This installer currently supports Debian/Ubuntu systems with apt-get.
  The EZ Tools download set is currently the upstream net9 flavor. The .NET
  channel is configurable for testing, but the tools themselves still depend on
  the framework version Eric Zimmerman publishes.
EOF
}

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

die() {
  colorize red "ERROR: $*"
  exit 1
}

cleanup() {
  if [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi
}
trap cleanup EXIT

require_option_value() {
  local option="$1"
  local argc="$2"
  local value="${3:-}"

  [[ "${argc}" -ge 2 && -n "${value}" ]] || die "${option} requires a value"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t|--tools)
        require_option_value "$1" "$#" "${2:-}"
        SELECTED_TOOLS="$2"
        shift 2
        ;;
      -d|--dest)
        require_option_value "$1" "$#" "${2:-}"
        INSTALL_ROOT="$2"
        shift 2
        ;;
      -c|--dotnet-channel)
        require_option_value "$1" "$#" "${2:-}"
        DOTNET_CHANNEL="$2"
        shift 2
        ;;
      -k|--dotnet-kind)
        require_option_value "$1" "$#" "${2:-}"
        DOTNET_KIND="$2"
        shift 2
        ;;
      -r|--runtime-only)
        DOTNET_KIND="runtime"
        shift
        ;;
      -s|--sdk)
        DOTNET_KIND="sdk"
        shift
        ;;
      -p|--profile)
        require_option_value "$1" "$#" "${2:-}"
        PROFILE_FILE="$2"
        shift 2
        ;;
      -n|--no-profile)
        UPDATE_PROFILE=false
        shift
        ;;
      -w|--wrapper-dir)
        require_option_value "$1" "$#" "${2:-}"
        WRAPPER_DIR="$2"
        shift 2
        ;;
      -f|--force)
        FORCE=true
        shift
        ;;
      -y|--yes)
        ASSUME_YES=true
        shift
        ;;
      -D|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      --skip-dotnet-signature-check)
        VERIFY_DOTNET_SIGNATURE=false
        shift
        ;;
      --allow-root)
        ALLOW_ROOT=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done

  [[ -n "${SELECTED_TOOLS}" ]] || die "--tools requires a value"
  [[ -n "${INSTALL_ROOT}" ]] || die "--dest requires a value"
  [[ -n "${DOTNET_CHANNEL}" ]] || die "--dotnet-channel requires a value"
  [[ "${DOTNET_KIND}" == "sdk" || "${DOTNET_KIND}" == "runtime" ]] || die "--dotnet-kind must be sdk or runtime"

  DOTNET_INSTALL_ROOT="${HOME}/.dotnet"
  DOTNET_ROOT="${DOTNET_INSTALL_ROOT}"
  DOTNET_BIN="${DOTNET_INSTALL_ROOT}/dotnet"
}

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

confirm() {
  local prompt="$1"
  local reply

  if [[ "${ASSUME_YES}" == true || "${DRY_RUN}" == true ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    die "Confirmation is required in non-interactive mode. Re-run with --yes to proceed."
  fi

  read -r -p "${prompt} [Y/n] " reply
  case "${reply}" in
    ""|y|Y|yes|YES) return 0 ;;
    n|N|no|NO) die "Installation cancelled by user." ;;
    *) die "Installation cancelled by user." ;;
  esac
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
  success "Prerequisites installed."
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
  success ".NET ${DOTNET_KIND} channel ${DOTNET_CHANNEL} installed."
}

normalize_tool_selection() {
  local normalized="${SELECTED_TOOLS,,}"
  printf '%s\n' "${normalized//[[:space:]]/}"
}

tool_selected() {
  local key="$1"
  local normalized
  normalized="$(normalize_tool_selection)"
  local selection=",${normalized},"

  [[ "${selection}" == ",all," || "${selection}" == *",${key},"* ]]
}

validate_tool_selection() {
  local normalized
  local requested
  local requested_tool
  local found
  local item
  local key
  local _name
  local _url
  local _extract_subdir
  local _dll_path
  local _expected_sha256

  normalized="$(normalize_tool_selection)"
  IFS=',' read -ra requested <<< "${normalized}"

  for requested_tool in "${requested[@]}"; do
    [[ -n "${requested_tool}" ]] || continue
    [[ "${requested_tool}" == "all" ]] && continue
    found=false

    for item in "${TOOL_MANIFEST[@]}"; do
      IFS='|' read -r key _name _url _extract_subdir _dll_path _expected_sha256 <<< "${item}"
      if [[ "${requested_tool}" == "${key}" ]]; then
        found=true
        break
      fi
    done

    [[ "${found}" == true ]] || die "Unknown tool '${requested_tool}'. Valid values: $(valid_tool_keys)"
  done
}

valid_tool_keys() {
  local keys=(all)
  local item key _name _url _extract_subdir _dll_path _expected_sha256

  for item in "${TOOL_MANIFEST[@]}"; do
    IFS='|' read -r key _name _url _extract_subdir _dll_path _expected_sha256 <<< "${item}"
    keys+=("${key}")
  done

  local IFS=,
  printf '%s\n' "${keys[*]}"
}

selected_tool_labels() {
  local labels=()
  local item key name _url _extract_subdir _dll_path _expected_sha256

  for item in "${TOOL_MANIFEST[@]}"; do
    IFS='|' read -r key name _url _extract_subdir _dll_path _expected_sha256 <<< "${item}"
    if tool_selected "${key}"; then
      labels+=("${name}")
    fi
  done

  if [[ "${#labels[@]}" -eq 0 ]]; then
    die "No tools selected. Valid values: $(valid_tool_keys)"
  fi

  printf '%s\n' "${labels[*]}"
}

# Some ZIPs unzip flat into their target directory, while others include a
# top-level directory inside the archive.
absolute_tool_path() {
  local extract_subdir="$1"
  local dll_path="$2"

  if [[ "${extract_subdir}" == "." ]]; then
    printf '%s/%s\n' "${INSTALL_ROOT}" "${dll_path}"
  else
    printf '%s/%s/%s\n' "${INSTALL_ROOT}" "${extract_subdir}" "${dll_path}"
  fi
}

# EZ Tool checksums are not currently published in the direct download flow, but
# the manifest supports them so they can be added without changing installer flow.
verify_checksum_if_present() {
  local file="$1"
  local expected_sha256="$2"
  local actual_sha256

  [[ -n "${expected_sha256}" ]] || return 0

  actual_sha256="$(sha256sum "${file}" | awk '{print $1}')"
  [[ "${actual_sha256}" == "${expected_sha256}" ]] || die "Checksum mismatch for ${file}"
}

# Download, validate, and extract one manifest entry.
install_tool() {
  local name="$1"
  local url="$2"
  local extract_subdir="$3"
  local dll_path="$4"
  local expected_sha256="$5"
  local zip_name
  local zip_path
  local extract_dest
  local tool_dll

  tool_dll="$(absolute_tool_path "${extract_subdir}" "${dll_path}")"
  if [[ "${FORCE}" != true && -f "${tool_dll}" ]]; then
    success "${name} already installed at ${tool_dll}."
    return 0
  fi

  confirm "Install ${name} into ${INSTALL_ROOT}?"

  [[ -n "${TMP_DIR}" && -d "${TMP_DIR}" ]] || TMP_DIR="$(mktemp -d)"
  zip_name="$(basename "${url}")"
  zip_path="${TMP_DIR}/${zip_name}"

  download_file "${url}" "${zip_path}"
  if [[ "${DRY_RUN}" != true ]]; then
    verify_checksum_if_present "${zip_path}" "${expected_sha256}"
    unzip -t "${zip_path}" >/dev/null
  else
    log "[dry-run] Validate ${zip_name} archive integrity"
  fi

  if [[ "${extract_subdir}" == "." ]]; then
    extract_dest="${INSTALL_ROOT}"
  else
    extract_dest="${INSTALL_ROOT}/${extract_subdir}"
  fi

  run_sudo_cmd "Creating ${extract_dest}" mkdir -p "${extract_dest}"
  run_sudo_cmd "Extracting ${name}" unzip -oq "${zip_path}" -d "${extract_dest}"

  if [[ "${DRY_RUN}" != true && ! -f "${tool_dll}" ]]; then
    die "${name} install completed, but expected DLL was not found at ${tool_dll}"
  fi

  success "${name} installed."
}

# Install only selected manifest entries.
install_tools() {
  local item key name url extract_subdir dll_path expected_sha256

  for item in "${TOOL_MANIFEST[@]}"; do
    IFS='|' read -r key name url extract_subdir dll_path expected_sha256 <<< "${item}"
    if tool_selected "${key}"; then
      install_tool "${name}" "${url}" "${extract_subdir}" "${dll_path}" "${expected_sha256}"
    fi
  done
}

# Wrappers make the tools usable from scripts and shells without relying on aliases.
write_wrapper() {
  local command_name="$1"
  local dll_path="$2"
  local wrapper_path="${WRAPPER_DIR}/${command_name}"
  local temp_wrapper

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] Create wrapper ${wrapper_path} -> ${dll_path}"
    return 0
  fi

  temp_wrapper="$(mktemp)"
  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' 'set -euo pipefail'
    printf "DOTNET_BIN=\"\${DOTNET_BIN:-%s}\"\n" "${DOTNET_BIN}"
    printf "exec \"\${DOTNET_BIN}\" \"%s\" \"\$@\"\n" "${dll_path}"
  } > "${temp_wrapper}"

  chmod 0755 "${temp_wrapper}"
  run_sudo_cmd "Installing wrapper ${wrapper_path}" install -m 0755 "${temp_wrapper}" "${wrapper_path}"
  rm -f "${temp_wrapper}"
}

install_wrappers() {
  local item key _name _url extract_subdir dll_path _expected_sha256 tool_dll

  run_sudo_cmd "Creating wrapper directory ${WRAPPER_DIR}" mkdir -p "${WRAPPER_DIR}"

  for item in "${TOOL_MANIFEST[@]}"; do
    IFS='|' read -r key _name _url extract_subdir dll_path _expected_sha256 <<< "${item}"
    if tool_selected "${key}"; then
      tool_dll="$(absolute_tool_path "${extract_subdir}" "${dll_path}")"
      write_wrapper "${key}" "${tool_dll}"
    fi
  done

  success "Command wrappers installed in ${WRAPPER_DIR}."
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

# Fail the installer if the resulting commands are present but cannot start.
validate_installation() {
  local failures=0
  local item key name _url extract_subdir dll_path _expected_sha256 tool_dll
  local wrapper_path validation_log

  if [[ "${DRY_RUN}" == true ]]; then
    log "[dry-run] Skip post-install validation"
    return 0
  fi

  if [[ ! -x "${DOTNET_BIN}" ]]; then
    warn ".NET binary not found at ${DOTNET_BIN}"
    failures=$((failures + 1))
  else
    "${DOTNET_BIN}" --info >/dev/null || failures=$((failures + 1))
  fi

  for item in "${TOOL_MANIFEST[@]}"; do
    IFS='|' read -r key name _url extract_subdir dll_path _expected_sha256 <<< "${item}"
    if ! tool_selected "${key}"; then
      continue
    fi

    tool_dll="$(absolute_tool_path "${extract_subdir}" "${dll_path}")"
    if [[ ! -f "${tool_dll}" ]]; then
      warn "${name} DLL missing: ${tool_dll}"
      failures=$((failures + 1))
      continue
    fi

    wrapper_path="${WRAPPER_DIR}/${key}"
    if [[ ! -x "${wrapper_path}" ]]; then
      warn "${key} wrapper missing from ${WRAPPER_DIR}"
      failures=$((failures + 1))
      continue
    fi

    validation_log="$(mktemp)"
    if timeout 20 env DOTNET_BIN="${DOTNET_BIN}" "${wrapper_path}" --help >"${validation_log}" 2>&1; then
      rm -f "${validation_log}"
    else
      warn "${name} wrapper did not pass --help validation: ${wrapper_path}"
      sed -n '1,8p' "${validation_log}" >&2
      rm -f "${validation_log}"
      failures=$((failures + 1))
    fi
  done

  [[ "${failures}" -eq 0 ]] || die "Post-install validation failed with ${failures} issue(s)."
  success "Post-install validation passed."
}

print_plan() {
  local tools
  tools="$(selected_tool_labels)"

  log "--------------------------------------------------------------------------------------------"
  log "Install_EZTools plan"
  log "  Platform: Debian/Ubuntu via apt-get"
  log "  Tools: ${tools}"
  log "  EZ Tools root: ${INSTALL_ROOT}"
  log "  Wrapper directory: ${WRAPPER_DIR}"
  log "  .NET install: ${DOTNET_KIND}, channel ${DOTNET_CHANNEL}, managed root ${DOTNET_INSTALL_ROOT}"
  log "  .NET binary to check first: ${DOTNET_BIN}"
  log "  Update profile: ${UPDATE_PROFILE} (${PROFILE_FILE})"
  log "  Verify dotnet-install.sh signature: ${VERIFY_DOTNET_SIGNATURE}"
  log "  Force reinstall: ${FORCE}"
  log "  Dry run: ${DRY_RUN}"
  log "--------------------------------------------------------------------------------------------"
}

main() {
  parse_args "$@"
  require_not_root
  require_debian_ubuntu
  require_commands
  detect_existing_dotnet
  validate_tool_selection
  print_plan
  confirm "Proceed with this installation plan?"
  install_prereqs
  install_dotnet
  install_tools
  install_wrappers
  update_profile
  validate_installation
  success "Installation complete. Open a new shell or source ${PROFILE_FILE} before using the wrappers."
}

main "$@"
