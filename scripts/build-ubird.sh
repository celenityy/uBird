#!/bin/bash

set -euo pipefail

# Set verbosity
set_verbosity

# Ensure we have `UBIRD_SCRIPTS`
verify_dir_with_env "${UBIRD_SCRIPTS}" 'UBIRD_SCRIPTS' || return 1

# Include patch utilities
verify_file "${UBIRD_SCRIPTS}/patches.sh" || return 1
source "${UBIRD_SCRIPTS}/patches.sh" || return 1

if [[ -z "${UBIRD_FROM_BUILD+x}" ]]; then
  echo_red_text "ERROR: Do not call 'build-ubird.sh' directly! Instead, use 'build.sh'." >&1
  return 1
fi

verify_env "${build_target}" 'build_target' || {
  echo_red_text "ERROR: Missing build target!"
  return 1
}

# Set-up target parameters
UBIRD_BUILD_ATN=0
UBIRD_BUILD_DIRECT=0

if [[ "${build_target}" == 'atn' ]]; then
  # Build uBird (ATN)
  UBIRD_BUILD_ATN=1
elif [[ "${build_target}" == 'direct' ]]; then
  # Build uBird (Self-distribution)
  UBIRD_BUILD_DIRECT=1
elif [[ "${build_target}" == 'all' ]]; then
  # If no argument is specified (or argument is set to "all"), just build both
  UBIRD_BUILD_ATN=1
  UBIRD_BUILD_DIRECT=1
else
  echo_red_text "ERROR: Invalid target: '${build_target}'\n You must enter one of the following:"
  echo 'uBird (Self-distribution):  direct (Default)'
  echo 'uBird (ATN):                atn'
  return 1
fi
readonly UBIRD_BUILD_ATN
readonly UBIRD_BUILD_DIRECT

# Ensure we have cp
verify_exec "${UBIRD_CP}" 'UBIRD_CP' || return 1

# Ensure we have mkdir
verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || return 1

# Ensure we have Python
verify_exec "${UBIRD_PYTHON}" 'UBIRD_PYTHON' || return 1

# Ensure we have rm
verify_exec "${UBIRD_RM}" 'UBIRD_RM' || return 1

# Ensure we have `UBIRD_TEMP`
verify_env "${UBIRD_TEMP}" 'UBIRD_TEMP' || return 1

# Ensure we have `UBIRD_VERSION
verify_env "${UBIRD_VERSION}" 'UBIRD_VERSION' || return 1

# Ensure we have `UBIRD_UBLOCK_VERSION
verify_env "${UBIRD_UBLOCK_VERSION}" 'UBIRD_UBLOCK_VERSION' || return 1

# Ensure we have `UBIRD_ADDON_ID`
if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
  verify_env "${UBIRD_ADDON_ID}" 'UBIRD_ADDON_ID' || return 1
fi

# Ensure we have `UBIRD_ATN_ADDON_ID`
if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
  verify_env "${UBIRD_ATN_ADDON_ID}" 'UBIRD_ATN_ADDON_ID' || return 1
fi

# Ensure we have `UBIRD_UPDATE_URL`
if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
  verify_env "${UBIRD_UPDATE_URL}" 'UBIRD_UPDATE_URL' || return 1
fi

# Ensure we have `UBIRD_UBO`
verify_dir_with_env "${UBIRD_UBO}" 'UBIRD_UBO' || return 1

# Ensure we have `UBIRD_UASSETS_MAIN`
verify_dir_with_env "${UBIRD_UASSETS_MAIN}" 'UBIRD_UASSETS_MAIN' || return 1

# Ensure we have `UBIRD_UASSETS_PROD`
verify_dir_with_env "${UBIRD_UASSETS_PROD}" 'UBIRD_UASSETS_PROD' || return 1

# Set-up a Python environment
function setup_pyenv() {
  # The Python environment *should* already be created by `get_sources.sh`, but it may not be (ex. if the user provides their own Python and/or
  # doesn't use `get_sources.sh`), so if it doesn't exist then create it
  if [[ ! -f "${UBIRD_PYENV}" ]]; then
    # Preferably, we want to use uv, but if uv is unavailable, we can try falling back to Python's built-in venv module
    UBIRD_UV_AVAILABLE=1
    verify_exec "${UBIRD_UV}" 'UBIRD_UV' || UBIRD_UV_AVAILABLE=0
    if [[ "${UBIRD_UV_AVAILABLE}" == 1 ]]; then
      echo_red_text 'Creating Python environment with uv...'
      "${UBIRD_UV}" venv "${UBIRD_PYENV_DIR}"
    else
      echo_red_text 'Creating Python environment with Python...'
      "${UBIRD_PYTHON}" -m venv "${UBIRD_PYENV_DIR}"
    fi
    echo_green_text "SUCCESS: Created Python environment: '${UBIRD_PYENV}'!"
  fi

  verify_file_with_env "${UBIRD_PYENV}" 'UBIRD_PYENV' || return 1
  echo_red_text "Sourcing Python environment: '${UBIRD_PYENV}'..."
  source "${UBIRD_PYENV}" || exit 1
  echo_green_text "SUCCESS: Sourced Python environment: '${UBIRD_PYENV}'!"
}

# Prepare to build uBird
function prep_ubird() {
  # Ensure we have ln
  verify_exec "${UBIRD_LN}" 'UBIRD_LN' || return 1

  # First, validate our patches
  local -r ubo_manifest="${UBIRD_UBO}/platform/thunderbird/manifest.json"
  if [[ -f "${UBIRD_TEMP}/manifest.json" ]]; then
    "${UBIRD_CP}" "${UBIRD_TEMP}/manifest.json" "${ubo_manifest}"
  fi
  pushd "${UBIRD_UBO}"
  local patch_validation_failed=0

  if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]] && ! check_patches; then
    local patch_validation_failed=1
  fi

  if [[ "${UBIRD_BUILD_ATN}" == 1 ]] && ! check_patches_atn; then
    local patch_validation_failed=1
  fi
  popd

  if [[ "${patch_validation_failed}" == 1 ]]; then
    echo_red_text "ERROR: Patch validation failed! Please check the patch files and try again."
    return 1
  fi

  # Symlink uAssets
  if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets" ]]; then
    "${UBIRD_MKDIR}" -p "${UBIRD_UBO}/dist/build/uAssets"
  fi

  # Symlink uAssets (main)
  if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets/main" ]]; then
    "${UBIRD_LN}" -sf "${UBIRD_UASSETS_MAIN}" "${UBIRD_UBO}/dist/build/uAssets/main"
  fi

  # Symlink uAssets (prod)
  if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets/prod" ]]; then
    "${UBIRD_LN}" -sf "${UBIRD_UASSETS_PROD}" "${UBIRD_UBO}/dist/build/uAssets/prod"
  fi

  # Copy uBlock Origin's manifest
  if [[ ! -f "${UBIRD_TEMP}/manifest.json" ]]; then
    verify_file "${ubo_manifest}" || {
      echo_red_text "ERROR: Missing uBlock Origin manifest: '${ubo_manifest}'!"
      return 1
    }
    "${UBIRD_CP}" "${ubo_manifest}" "${UBIRD_TEMP}/manifest.json"
  fi

  # Remove the manifest (so we can replace it)
  "${UBIRD_RM}" "${ubo_manifest}"
}

# Build uBird
function build_ubird() {
  function print_usage() {
    echo "Usage: build_ubird 'variant'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text "ERROR: Please specify the variant of uBird you'd like to build!"
    print_usage
    return 1
  fi

  # Ensure we have bash
  verify_exec "${UBIRD_BASH}" 'UBIRD_BASH' || return 1

  # Ensure we have GNU sed
  verify_exec "${UBIRD_SED}" 'UBIRD_SED' || return 1

  # Ensure we have our manifest
  verify_file "${UBIRD_TEMP}/manifest.json" || return 1

  local -r variant="$1"

  if [[ "${variant}" == 'direct' ]]; then
    local -r addon_id="${UBIRD_ADDON_ID}"
    local -r output_name="ubird-${UBIRD_VERSION}"
    local -r variant_pretty='Self-distribution'
  elif [[ "${variant}" == 'atn' ]]; then
    local -r addon_id="${UBIRD_ATN_ADDON_ID}"
    local -r output_name="ubird-${UBIRD_VERSION}-atn"
    local -r variant_pretty='ATN'
  else
    echo_red_text "ERROR: Unknown target variant: '${variant}'!"
    return 1
  fi

  echo_red_text "Building uBird: '${UBIRD_VERSION}' (${variant_pretty})..."

  # Create our temporary working directory
  local -r temp_dir="${UBIRD_TEMP}/ubird-${variant}"
  if [[ -d "${temp_dir}" ]]; then
    "${UBIRD_RM}" -rf "${temp_dir}"
  fi
  "${UBIRD_MKDIR}" -p "${temp_dir}"

  # Patch our manifest
  local -r ubo_manifest="${UBIRD_UBO}/platform/thunderbird/manifest.json"
  if [[ -f "${ubo_manifest}" ]]; then
    "${UBIRD_RM}" "${ubo_manifest}"
  fi
  "${UBIRD_CP}" "${UBIRD_TEMP}/manifest.json" "${ubo_manifest}"

  pushd "${UBIRD_UBO}"
  if [[ "${variant}" == 'direct' ]]; then
    apply_patches || return 1
  elif [[ "${variant}" == 'atn' ]]; then
    apply_patches_atn || return 1
  else
    echo_red_text "ERROR: Unknown target variant: '${variant}'!"
    return 1
  fi

  # Copy our manifest
  local -r temp_manifest="${temp_dir}/manifest.json"
  "${UBIRD_CP}" "${ubo_manifest}" "${temp_manifest}"
  "${UBIRD_RM}" "${ubo_manifest}"

  # Set our add-on ID
  "${UBIRD_SED}" -i -e "s|\"id\": \".*\"|\"id\": \"${addon_id}\"|g" "${temp_manifest}"
  "${UBIRD_SED}" -i -e "s|uBlock0@raymondhill.net|${addon_id}|g" "${temp_manifest}"

  # Set our version
  local -r ubo_version_file="${UBIRD_UBO}/dist/version"
  if [[ -f "${ubo_version_file}" ]]; then
    "${UBIRD_RM}" "${ubo_version_file}"
  fi
  echo -n "${UBIRD_VERSION}" > "${ubo_version_file}"
  "${UBIRD_SED}" -i -e "s|\"version\": \".*\"|\"version\": \"${UBIRD_VERSION}\"|g" "${temp_manifest}"

  # Set our update URL
  if [[ "${variant}" == 'direct' ]]; then
    "${UBIRD_SED}" -i "s|{UBIRD_UPDATE_URL}|${UBIRD_UPDATE_URL}|" "${temp_manifest}"
  fi

  # Now that it's parsed, copy our manifest
  "${UBIRD_CP}" "${temp_manifest}" "${ubo_manifest}"

  # Build uBird
  verify_file "${UBIRD_UBO}/tools/make-thunderbird.sh" || return 1
  "${UBIRD_BASH}" "${UBIRD_UBO}/tools/make-thunderbird.sh" all || return 1
  popd

  # Create our output directory
  if [[ ! -d "${UBIRD_OUTPUTS}" ]]; then
    "${UBIRD_MKDIR}" -p "${UBIRD_OUTPUTS}"
  fi

  # Copy our output
  local -r ubird_output="${UBIRD_OUTPUTS}/${output_name}.xpi"
  if [[ -f "${ubird_output}" ]]; then
    echo_red_text "WARNING: Output file: '${ubird_output}' already exists!"
    echo_red_text "Continuing WILL override this build"
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      echo_red_text "Removing '${ubird_output}'..."
      "${IRONFOX_RM}" -f "${ubird_output}"
    else
      return 1
    fi
  fi
  "${UBIRD_CP}" "${UBIRD_UBO}/dist/build/uBlock0.thunderbird.xpi" "${ubird_output}"

  # Clean-up
  "${UBIRD_RM}" "${ubo_manifest}"

  echo_green_text "SUCCESS: Built uBird: '${UBIRD_VERSION}' (${variant_pretty})!"
}

# Create our temporary file directory
"${UBIRD_MKDIR}" -p "${UBIRD_TEMP}"

# Set-up a Python environment
setup_pyenv

# Prepare to build uBird
prep_ubird

# Build uBird (Self-distribution)
if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
  build_ubird 'direct'
fi

# Build uBird (ATN)
if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
  build_ubird 'atn'
fi
