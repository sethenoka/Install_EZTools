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

  completed_or_planned "${name} files installed." "${name} files would be installed."
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

  completed_or_planned \
    "Command wrappers installed in ${WRAPPER_DIR}." \
    "Command wrappers would be installed in ${WRAPPER_DIR}."
}

# Some tools print platform/runtime failures but still exit cleanly, so validation
# checks both exit status and output content.
validation_output_has_failure() {
  local output_file="$1"

  grep -Eiq \
    'Non-Windows platforms not supported|not supported due to|unsupported platform|Unhandled exception|A fatal error occurred|You must install or update \.NET|No frameworks were found' \
    "${output_file}"
}

print_validation_error() {
  local name="$1"
  local wrapper_path="$2"
  local output_file="$3"

  warn "${name} wrapper did not pass --help validation: ${wrapper_path}"
  sed -n '1,8p' "${output_file}" >&2
}

# Fail the installer if the resulting commands are present but cannot start.
validate_installation() {
  local failures=0
  local item key name _url extract_subdir dll_path _expected_sha256 tool_dll
  local wrapper_path validation_log
  local validation_status

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
    validation_status=0
    timeout 20 env DOTNET_BIN="${DOTNET_BIN}" "${wrapper_path}" --help >"${validation_log}" 2>&1 || validation_status=$?

    if [[ "${validation_status}" -ne 0 ]] || validation_output_has_failure "${validation_log}"; then
      print_validation_error "${name}" "${wrapper_path}" "${validation_log}"
      rm -f "${validation_log}"
      failures=$((failures + 1))
      continue
    fi

    rm -f "${validation_log}"
  done

  [[ "${failures}" -eq 0 ]] || die "Post-install validation failed with ${failures} issue(s)."
  success "Post-install validation passed."
}
