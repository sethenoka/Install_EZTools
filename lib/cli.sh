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
  Boolean short flags can be bundled, e.g. -yvf is equivalent to -y -v -f.
  Short options that take values, such as -t LIST and -d DIR, cannot be bundled.
  This installer currently supports Debian/Ubuntu systems with apt-get.
  The EZ Tools download set is currently the upstream net9 flavor. The .NET
  channel is configurable for testing, but the tools themselves still depend on
  the framework version Eric Zimmerman publishes.
EOF
}

require_option_value() {
  local option="$1"
  local argc="$2"
  local value="${3:-}"

  [[ "${argc}" -ge 2 && -n "${value}" ]] || die "${option} requires a value"
}

apply_short_flag() {
  local flag="$1"

  case "${flag}" in
    r) DOTNET_KIND="runtime" ;;
    s) DOTNET_KIND="sdk" ;;
    n) UPDATE_PROFILE=false ;;
    f) FORCE=true ;;
    y) ASSUME_YES=true ;;
    D) DRY_RUN=true ;;
    v) VERBOSE=true ;;
    h)
      usage
      exit 0
      ;;
    *) die "Unknown short option: -${flag}" ;;
  esac
}

parse_args() {
  local bundled_flags

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -[!-]?*)
        bundled_flags="${1#-}"
        while [[ -n "${bundled_flags}" ]]; do
          apply_short_flag "${bundled_flags:0:1}"
          bundled_flags="${bundled_flags:1}"
        done
        shift
        ;;
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
