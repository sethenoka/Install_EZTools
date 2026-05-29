#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"

# shellcheck source=lib/config.sh
. "${SCRIPT_DIR}/lib/config.sh"
# shellcheck source=lib/logging.sh
. "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/cli.sh
. "${SCRIPT_DIR}/lib/cli.sh"
# shellcheck source=lib/system.sh
. "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=lib/tools.sh
. "${SCRIPT_DIR}/lib/tools.sh"

trap cleanup EXIT

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

  if [[ "${DRY_RUN}" == true ]]; then
    success "Dry run complete. No changes were made."
  else
    success "Installation complete. Open a new shell or run: source ${PROFILE_FILE}"
  fi
}

main "$@"
