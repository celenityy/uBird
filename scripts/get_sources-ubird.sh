#!/bin/bash

set -euo pipefail

# Set-up our environment
source $(dirname $0)/env.sh || exit 1

# Include utilities
source "${UBIRD_UTILS}" || exit 1

# Set verbosity
set_verbosity

# Include download utilities
source "${UBIRD_DOWNLOAD_UTILS}" || exit 1

# Include file utilities
source "${UBIRD_FILE_UTILS}" || exit 1

if [[ -z "${UBIRD_FROM_SOURCES+x}" ]]; then
  echo_red_text "ERROR: Do not call 'get_sources-ubird.sh' directly! Instead, use 'get_sources.sh'." >&1
  exit 1
fi

# Ensure we have rm
verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

readonly target="$1"
readonly mode="$2"

# Set-up target parameters
UBIRD_GET_SOURCE_PYTHON=0
UBIRD_GET_SOURCE_SHELLCHECK=0
UBIRD_GET_SOURCE_SHFMT=0
UBIRD_GET_SOURCE_UASSETS_MAIN=0
UBIRD_GET_SOURCE_UASSETS_PROD=0
UBIRD_GET_SOURCE_UBLOCK=0
UBIRD_GET_SOURCE_UV=0

if [[ "${target}" == 'python' ]]; then
  # Get Python
  UBIRD_GET_SOURCE_PYTHON=1
elif [[ "${target}" == 'shellcheck' ]]; then
  # Get shellcheck
  UBIRD_GET_SOURCE_SHELLCHECK=1
elif [[ "${target}" == 'shfmt' ]]; then
  # Get shfmt
  UBIRD_GET_SOURCE_SHFMT=1
elif [[ "${target}" == 'uassets-main' ]]; then
  # Get uAssets (main)
  UBIRD_GET_SOURCE_UASSETS_MAIN=1
elif [[ "${target}" == 'uassets-prod' ]]; then
  # Get uAssets (prod)
  UBIRD_GET_SOURCE_UASSETS_PROD=1
elif [[ "${target}" == 'ublock' ]]; then
  # Get uBlock Origin
  UBIRD_GET_SOURCE_UBLOCK=1
elif [[ "${target}" == 'uv' ]]; then
  # Get + set-up uv
  UBIRD_GET_SOURCE_UV=1
elif [[ "${target}" == 'all' ]]; then
  # If no argument is specified (or argument is set to "all"), just get everything
  UBIRD_GET_SOURCE_PYTHON=1
  UBIRD_GET_SOURCE_UASSETS_MAIN=1
  UBIRD_GET_SOURCE_UASSETS_PROD=1
  UBIRD_GET_SOURCE_UBLOCK=1
  UBIRD_GET_SOURCE_UV=1

  # CI only uses shellcheck and shfmt in the `lint` stage (where they're retrieved directly)
  # If git is missing, we know the user isn't contributing (at least from this repo directly), so we don't need to download them in
  # those cases either
  if [[ -x "${UBIRD_GIT}" ]] && [[ "${UBIRD_CI}" != 1 ]]; then
    UBIRD_GET_SOURCE_SHELLCHECK=1
    UBIRD_GET_SOURCE_SHFMT=1
  fi
else
  echo_red_text "ERROR: Invalid target: ${target}\n You must enter one of the following:"
  echo 'All:              all (Default)'
  echo 'Python:           python'
  echo 'shellcheck:       shellcheck'
  echo 'shfmt:            shfmt'
  echo 'uAssets (main):   uassets-main'
  echo 'uAssets (prod):   uassets-prod'
  echo 'uBlock Origin:    ublock'
  echo 'uv:               uv'
  exit 1
fi
readonly UBIRD_GET_SOURCE_PYTHON
readonly UBIRD_GET_SOURCE_SHELLCHECK
readonly UBIRD_GET_SOURCE_SHFMT
readonly UBIRD_GET_SOURCE_UASSETS_MAIN
readonly UBIRD_GET_SOURCE_UASSETS_PROD
readonly UBIRD_GET_SOURCE_UBLOCK
readonly UBIRD_GET_SOURCE_UV

# If the 'checksum-update' argument is specified, in addition to downloading the dependencies as usual,
## we're also updating their checksums
UBIRD_GET_SOURCE_CHECKSUM_UPDATE=0
if [[ "${mode}" == 'checksum-update' ]]; then
  UBIRD_GET_SOURCE_CHECKSUM_UPDATE=1
elif [[ "${mode}" != 'download' ]]; then
  echo_red_text "ERROR: Invalid mode: ${mode}\n You must enter one of the following:"
  echo 'Download:                     download (Default)'
  echo 'Download + update checksums:  checksum-update'
  exit 1
fi
readonly UBIRD_GET_SOURCE_CHECKSUM_UPDATE

# Include version info
source "${UBIRD_VERSIONS}" || exit 1

# Back-up (and remove) a file if it exists
function backup_file() {
  function print_usage() {
    echo "Usage: backup_file 'path/to/file'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the file path!'
    print_usage
    exit 1
  fi

  # Ensure we have basename
  verify_exec "${UBIRD_BASENAME}" 'UBIRD_BASENAME' || exit 1

  # Ensure we have cp
  verify_exec "${UBIRD_CP}" 'UBIRD_CP' || exit 1

  # Ensure we have dirname
  verify_exec "${UBIRD_DIRNAME}" 'UBIRD_DIRNAME' || exit 1

  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r file="$1"
  local -r file_name="$("${UBIRD_BASENAME}" "${file}")"
  local -r backup_file="${UBIRD_EXTERNAL}/temp/backup/${file_name}"

  if [[ -f "${file}" ]]; then
    "${UBIRD_RM}" -f "${backup_file}"
    "${UBIRD_MKDIR}" -p "$("${UBIRD_DIRNAME}" "${backup_file}")"
    "${UBIRD_CP}" -f "${file}" "${backup_file}"
    "${UBIRD_RM}" -f "${file}"
  fi
}

# Back-up (and remove) a directory if it exists
function backup_dir() {
  function print_usage() {
    echo "Usage: backup_dir 'path/to/directory'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the directory path!'
    print_usage
    exit 1
  fi

  # Ensure we have basename
  verify_exec "${UBIRD_BASENAME}" 'UBIRD_BASENAME' || exit 1

  # Ensure we have cp
  verify_exec "${UBIRD_CP}" 'UBIRD_CP' || exit 1

  # Ensure we have dirname
  verify_exec "${UBIRD_DIRNAME}" 'UBIRD_DIRNAME' || exit 1

  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r dir="$1"
  local -r dir_name="$("${UBIRD_BASENAME}" "${dir}")"
  local -r backup_dir="${UBIRD_EXTERNAL}/temp/backup/${dir_name}"

  if [[ -d "${dir}" ]]; then
    "${UBIRD_RM}" -rf "${backup_dir}"
    "${UBIRD_MKDIR}" -p "$("${UBIRD_DIRNAME}" "${backup_dir}")"
    "${UBIRD_CP}" -rf "${dir}/" "${backup_dir}"
    "${UBIRD_RM}" -rf "${dir}"
  fi
}

# Restore a backed-up file
function restore_file() {
  function print_usage() {
    echo "Usage: restore_file 'path/to/file'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the file path!'
    print_usage
    exit 1
  fi

  # Ensure we have basename
  verify_exec "${UBIRD_BASENAME}" 'UBIRD_BASENAME' || exit 1

  # Ensure we have cp
  verify_exec "${UBIRD_CP}" 'UBIRD_CP' || exit 1

  # Ensure we have dirname
  verify_exec "${UBIRD_DIRNAME}" 'UBIRD_DIRNAME' || exit 1

  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r file="$1"
  local -r file_name="$("${UBIRD_BASENAME}" "${file}")"
  local -r backed_up_file="${UBIRD_EXTERNAL}/temp/backup/${file_name}"

  if [[ -f "${backed_up_file}" ]]; then
    "${UBIRD_RM}" -f "${file}"
    "${UBIRD_MKDIR}" -p "$("${UBIRD_DIRNAME}" "${file}")"
    "${UBIRD_CP}" -f "${backed_up_file}" "${file}"
    "${UBIRD_RM}" -f "${backed_up_file}"
  fi
}

# Restore a backed-up directory
function restore_dir() {
  function print_usage() {
    echo "Usage: restore_dir 'path/to/directory'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the directory path!'
    print_usage
    exit 1
  fi

  # Ensure we have basename
  verify_exec "${UBIRD_BASENAME}" 'UBIRD_BASENAME' || exit 1

  # Ensure we have cp
  verify_exec "${UBIRD_CP}" 'UBIRD_CP' || exit 1

  # Ensure we have dirname
  verify_exec "${UBIRD_DIRNAME}" 'UBIRD_DIRNAME' || exit 1

  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r dir="$1"
  local -r dir_name="$("${UBIRD_BASENAME}" "${dir}")"
  local -r backed_up_dir="${UBIRD_EXTERNAL}/temp/backup/${dir_name}"

  if [[ -d "${backed_up_dir}" ]]; then
    "${UBIRD_RM}" -rf "${dir}"
    "${UBIRD_MKDIR}" -p "$("${UBIRD_DIRNAME}" "${dir}")"
    "${UBIRD_CP}" -rf "${backed_up_dir}/" "${dir}"
    "${UBIRD_RM}" -rf "${backed_up_dir}"
  fi
}

# Update the checksum of a file
function update_checksum() {
  function print_usage() {
    echo "Usage: update_checksum 'current_checksum' 'new_checksum' 'path/to/file' 'checksum_type'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text "ERROR: Please provide the file's current checksum!"
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text "ERROR: Please provide the file's new checksum!"
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text 'ERROR: Please provide the file path!'
    print_usage
    exit 1
  fi

  if [[ -z "${4+x}" ]]; then
    echo_red_text 'ERROR: Please provide the checksum type!'
    print_usage
    exit 1
  fi

  # Ensure we have GNU sed
  verify_exec "${UBIRD_SED}" 'UBIRD_SED' || exit 1

  # Ensure we can update `versions.sh`
  verify_file "${UBIRD_VERSIONS}" || exit 1

  local -r old_checksum="$1"
  local -r new_checksum="$2"
  local -r file="$3"
  local -r checksum_type="$4"

  if [[ "${checksum_type}" == 'md5sum' ]]; then
    local -r checksum_type_pretty='MD5sum'
  elif [[ "${checksum_type}" == 'sha1sum' ]]; then
    local -r checksum_type_pretty='SHA1sum'
  elif [[ "${checksum_type}" == 'sha256sum' ]]; then
    local -r checksum_type_pretty='SHA256sum'
  elif [[ "${checksum_type}" == 'sha512sum' ]]; then
    local -r checksum_type_pretty='SHA512sum'
  else
    echo_red_text "ERROR: Unsupported checksum type: '${checksum_type}'!"
    exit 1
  fi

  if [[ "${old_checksum}" == "${new_checksum}" ]]; then
    echo_red_text "Checksums for file: '${file}' already match! Skipping..."
    echo "Old ${checksum_type_pretty}: '${old_checksum}'"
    echo "New ${checksum_type_pretty}: '${new_checksum}'"
  else
    echo_red_text "Updating ${checksum_type_pretty} for file: '${file}'..."
    "${UBIRD_SED}" -i "s|'${old_checksum}'|'${new_checksum}'|g" "${UBIRD_VERSIONS}"
    echo_green_text "SUCCESS: Updated ${checksum_type_pretty} for file: '${file}'!"
  fi
}

# Validate the checksum of a file
function validate_checksum() {
  function print_usage() {
    echo "Usage: validate_checksum 'expected_checksum' 'path/to/file' 'checksum_type'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text "ERROR: Please provide the file's expected checksum!"
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text 'ERROR: Please provide the file path!'
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text 'ERROR: Please provide the checksum type!'
    print_usage
    exit 1
  fi

  # Ensure we have GNU awk
  verify_exec "${UBIRD_AWK}" 'UBIRD_AWK' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r expected_checksum="$1"
  local -r file="$2"
  local -r checksum_type="$3"

  if [[ "${checksum_type}" == 'md5sum' ]]; then
    # Ensure we have md5sum
    verify_exec "${UBIRD_MD5SUM}" 'UBIRD_MD5SUM' || exit 1
  else
    # Ensure we have shasum
    verify_exec "${UBIRD_SHASUM}" 'UBIRD_SHASUM' || exit 1
  fi

  # Ensure our file to validate is valid
  verify_file "${file}" || exit 1

  if [[ "${checksum_type}" == 'md5sum' ]]; then
    local -r checksum_type_pretty='MD5sum'
    local -r local_checksum=$("${UBIRD_MD5SUM}" "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha1sum' ]]; then
    local -r checksum_type_pretty='SHA1sum'
    local -r local_checksum=$("${UBIRD_SHASUM}" -a 1 "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha256sum' ]]; then
    local -r checksum_type_pretty='SHA256sum'
    local -r local_checksum=$("${UBIRD_SHASUM}" -a 256 "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha512sum' ]]; then
    local -r checksum_type_pretty='SHA512sum'
    local -r local_checksum=$("${UBIRD_SHASUM}" -a 512 "${file}" | "${UBIRD_AWK}" '{print $1}')
  else
    echo_red_text "ERROR: Unsupported checksum type: '${checksum_type}'!"
    exit 1
  fi

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    update_checksum "${expected_checksum}" "${local_checksum}" "${file}" "${checksum_type}"
  elif [[ "${local_checksum}" != "${expected_checksum}" ]]; then
    echo_red_text "ERROR: Checksum (${checksum_type_pretty}) validation for file failed: '${file}'!"
    echo "Expected ${checksum_type_pretty}:   '${expected_checksum}'"
    echo "Actual ${checksum_type_pretty}:     '${local_checksum}'"

    # If checksum validation fails, also just remove the file
    "${UBIRD_RM}" -f "${file}"

    exit 1
  else
    echo_green_text "SUCCESS: Validated checksum (${checksum_type_pretty}) for file: '${file}'!"
    echo "${checksum_type_pretty}: '${local_checksum}'"
  fi
}

# Download and verify the SHA512sum of a file
function download_file() {
  function print_usage() {
    echo "Usage: download_file 'https://totally.real.url/file' 'path/to/file' 'file_sha512sum'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the URL for the file to download!'
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text 'ERROR: Please provide the output file path!'
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text "ERROR: Please provide the file's SHA512sum!"
    print_usage
    exit 1
  fi

  # Ensure we have basename
  verify_exec "${UBIRD_BASENAME}" 'UBIRD_BASENAME' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r url="$1"
  local -r file_in="$2"
  local -r file_name=$("${UBIRD_BASENAME}" "${file_in}")
  local -r expected_sha512sum="$3"

  # By default, we want to exit upon an error
  if [[ -z "${UBIRD_DOWNLOAD_EXIT+x}" ]]; then
    UBIRD_DOWNLOAD_EXIT=1
  fi

  # By default, we want to perform post-download actions for sources
  ## (this includes things like ex. installing a dependency or creating/setting-up an environment)
  ## This isn't desired in some cases, like if we're updating checksums, or a user just cancels the download
  unset UBIRD_PERFORM_POST_DOWNLOAD
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    ## If we're just updating a checksum, we should never perform post-download actions
    UBIRD_PERFORM_POST_DOWNLOAD=0
  else
    UBIRD_PERFORM_POST_DOWNLOAD=1
  fi

  # If we're doing a checksum update, we download the file to a separate temporary directory, instead of our standard one
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp/chksm"
    local -r file="${UBIRD_EXTERNAL}/temp/chksm/${file_name}"
  else
    local -r file="${file_in}"
  fi

  if [[ -f "${file}" ]]; then
    echo_red_text "File already exists: '${file}'!"
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our file
      echo_red_text "Removing file: '${file}'..."
      backup_file "${file}"
      echo_green_text "SUCCESS: Removed file: '${file}'!"
    else
      unset UBIRD_DOWNLOAD_EXIT
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 0
    fi
  fi

  # By default, we know nothing has failed...
  local UBIRD_CHECKSUM_FAILED=0
  local UBIRD_DOWNLOAD_FAILED=0

  # Download our file
  download "${url}" "${file}" || local UBIRD_DOWNLOAD_FAILED=1

  # Verify (or update) SHA512sum
  validate_checksum "${expected_sha512sum}" "${file}" 'sha512sum' || local UBIRD_CHECKSUM_FAILED=1

  # If we're just updating the checksum, we're done, so go ahead and exit
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text 'ERROR: Download failed!'
      exit 1
    elif [[ "${UBIRD_CHECKSUM_FAILED}" == 1 ]]; then
      echo_red_text 'ERROR: Failed to update checksum!'
      exit 1
    else
      return 0
    fi
  fi

  # If the download (or checksum validation) failed, restore our back-up
  if [[ "${UBIRD_CHECKSUM_FAILED}" == 1 ]] || [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
    if [[ -f "${UBIRD_EXTERNAL}/temp/backup/${file_name}" ]]; then
      restore_file "${file}"
    fi
  fi

  # Clean-up
  "${UBIRD_RM}" -f "${UBIRD_EXTERNAL}/temp/backup/${file_name}"
  "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp/chksm"

  # If the download (or checksum validation) failed, exit
  if [[ "${UBIRD_CHECKSUM_FAILED}" == 1 ]] || [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
    if [[ "${UBIRD_DOWNLOAD_EXIT}" != 1 ]]; then
      unset UBIRD_DOWNLOAD_EXIT
      return 1
    else
      echo_red_text 'ERROR: Download failed!'
      exit 1
    fi
  fi
}

# Download and extract an archive
function download_and_extract() {
  function print_usage() {
    echo "Usage: download_and_extract 'https://totally.real.url/archive' 'path/to/extract/archive/to' 'archive_sha512sum'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please provide the URL for the archive to download!'
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text 'ERROR: Please provide the path that the archive should be extracted to!'
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text "ERROR: Please provide the archive's SHA512sum!"
    print_usage
    exit 1
  fi

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r url="$1"
  local -r path="$2"
  local -r expected_sha512sum="$3"

  # By default, we want to perform post-download actions for sources
  ## (this includes things like ex. installing a dependency or creating/setting-up an environment)
  ## This isn't desired in some cases, like if we're updating checksums, or a user just cancels the download
  unset UBIRD_PERFORM_POST_DOWNLOAD
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    ## If we're just updating a checksum, we should never perform post-download actions
    UBIRD_PERFORM_POST_DOWNLOAD=0
  else
    UBIRD_PERFORM_POST_DOWNLOAD=1
  fi

  if [[ -d "${path}" ]] && [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    echo_red_text "Path already exists: '${path}'!"
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our directory
      echo_red_text "Removing path: '${path}'..."
      backup_dir "${path}"
      echo_green_text "SUCCESS: Removed path: '${path}'!"
    else
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 0
    fi
  fi

  if [[ "${url}" =~ \.tar\.xz$ ]]; then
    local -r extension=".tar.xz"
  elif [[ "${url}" =~ \.tar\.gz$ ]]; then
    local -r extension=".tar.gz"
  elif [[ "${url}" =~ \.tar\.zst$ ]]; then
    local -r extension=".tar.zst"
  else
    local -r extension=".zip"
  fi

  # Tell `download` to return instead of exit upon an error
  UBIRD_DOWNLOAD_EXIT=0

  # By default, we know the download hasn't failed...
  local UBIRD_DOWNLOAD_FAILED=0

  # Set a temporary archive name
  local -r temp_archive_path_name=$("${UBIRD_BASENAME}" "${path}")
  local -r temp_archive_path="${UBIRD_DOWNLOADS}/${temp_archive_path_name}${extension}"

  # Download the archive
  download_file "${url}" "${temp_archive_path}" "${expected_sha512sum}" || local UBIRD_DOWNLOAD_FAILED=1

  # If we're just updating the checksum, we're done, so go ahead and exit
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text "ERROR: Download for archive failed: '${url}'!"
      exit 1
    else
      return 0
    fi
  fi

  # If the download failed, restore our back-up (if possible) and exit
  if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
    restore_dir "${path}"
    if [[ "${temp_archive_path_name}" == 'uv' ]]; then
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 1
    else
      echo_red_text "ERROR: Download for archive failed: '${url}'!"
      exit 1
    fi
  fi

  # Extract the archive
  extract_archive "${temp_archive_path}" "${path}"

  # Clean-up
  "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp/backup/${repo_name}"
}

# Get Python
function get_python() {
  # Ensure we have `UBIRD_PYTHON_GIT_RELEASE`
  if [[ -z "${UBIRD_PYTHON_GIT_RELEASE+x}" ]] || [[ "${UBIRD_PYTHON_GIT_RELEASE}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_PYTHON_GIT_RELEASE' is missing!"
    exit 1
  fi

  # Ensure we have `UBIRD_PYTHON_VERSION`
  if [[ -z "${UBIRD_PYTHON_VERSION+x}" ]] || [[ "${UBIRD_PYTHON_VERSION}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_PYTHON_VERSION' is missing!"
    exit 1
  fi

  # If all we're doing is updating the checksum, we don't care about existing installations
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    # Ensure we have rm
    verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

    # Ensure we have uv
    verify_exec "${UBIRD_UV}" 'UBIRD_UV' || {
      echo_red_text "ERROR: Unable to download and install Python without uv!"
      exit 1
    }

    if [[ -d "${UBIRD_PYENV_DIR}" ]]; then
      echo_red_text "The Python environment is already set-up at path: '${UBIRD_PYENV_DIR}'!"
      read -p "Do you want to re-create it? [y/N] " -n 1 -r
      echo
      if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our directory
        backup_dir "${UBIRD_PYENV_DIR}"
      fi
    fi

    if [[ -d "${UBIRD_PYTHON_DIR}" ]]; then
      echo_red_text "Found existing installation at path: '${UBIRD_PYTHON_DIR}'!"
      echo 'Continuing will remove this installation and related data.'
      read -p "Do you still want to continue? [y/N] " -n 1 -r
      echo
      if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our directories
        backup_dir "${UBIRD_PYENV_DIR}"
        backup_dir "${UBIRD_PYTHON_DIR}"
        backup_dir "${UBIRD_UV_CACHE}"
        backup_dir "${UBIRD_UV_LOCAL}/python-cache"
        backup_dir "${UBIRD_UV_PYTHON}"
      else
        return 0
      fi
    fi
  fi

  # Base download URL
  local -r base_url="https://github.com/astral-sh/python-build-standalone/releases/download/${UBIRD_PYTHON_GIT_RELEASE}"

  # Base output path
  local -r base_output="${UBIRD_PYTHON_DIR}/${UBIRD_PYTHON_GIT_RELEASE}"

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    echo_red_text 'Downloading Python (Linux - ARM64)...'
    download_file "${base_url}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz" "${base_output}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-aarch64-unknown-linux-gnu-install_only_stripped.tar.gz" "${UBIRD_PYTHON_SHA512SUM_LINUX_ARM64}"

    echo_red_text 'Downloading Python (Linux - x86_64)...'
    download_file "${base_url}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz" "${base_output}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz" "${UBIRD_PYTHON_SHA512SUM_LINUX_X86_64}"

    echo_red_text 'Downloading Python (OS X - ARM64)...'
    download_file "${base_url}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-aarch64-apple-darwin-install_only_stripped.tar.gz" "${base_output}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-aarch64-apple-darwin-install_only_stripped.tar.gz" "${UBIRD_PYTHON_SHA512SUM_OSX_ARM64}"

    echo_red_text 'Downloading Python (OS X - x86_64)...'
    download_file "${base_url}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-x86_64-apple-darwin-install_only_stripped.tar.gz" "${base_output}/cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-x86_64-apple-darwin-install_only_stripped.tar.gz" "${UBIRD_PYTHON_SHA512SUM_OSX_X86_64}"
  else
    # Ensure we have rm
    verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

    # Set our platform
    if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
      local -r UBIRD_PYTHON_PLATFORM='apple-darwin'
    else
      local -r UBIRD_PYTHON_PLATFORM='unknown-linux-gnu'
    fi

    # Set our platform architecture
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      local -r UBIRD_PYTHON_ARCH='aarch64'
    else
      local -r UBIRD_PYTHON_ARCH='x86_64'
    fi

    # Set our checksum to verify
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_PYTHON_SHA512SUM="${UBIRD_PYTHON_SHA512SUM_OSX_ARM64}"
      else
        local -r UBIRD_PYTHON_SHA512SUM="${UBIRD_PYTHON_SHA512SUM_LINUX_ARM64}"
      fi
    else
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_PYTHON_SHA512SUM="${UBIRD_PYTHON_SHA512SUM_OSX_X86_64}"
      else
        local -r UBIRD_PYTHON_SHA512SUM="${UBIRD_PYTHON_SHA512SUM_LINUX_X86_64}"
      fi
    fi

    # Tell `download` to return instead of exit upon an error
    UBIRD_DOWNLOAD_EXIT=0

    # By default, we know nothing has failed...
    local UBIRD_DOWNLOAD_FAILED=0
    local UBIRD_PYENV_FAILED=0
    local UBIRD_PYTHON_INSTALL_FAILED=0

    local -r dl_archive="cpython-${UBIRD_PYTHON_VERSION}+${UBIRD_PYTHON_GIT_RELEASE}-${UBIRD_PYTHON_ARCH}-${UBIRD_PYTHON_PLATFORM}-install_only_stripped.tar.gz"
    local -r dl_output="${base_output}/${dl_archive}"
    local -r dl_url="${base_url}/${dl_archive}"

    echo_red_text 'Downloading Python...'
    download_file "${dl_url}" "${dl_output}" "${UBIRD_PYTHON_SHA512SUM}" || local UBIRD_DOWNLOAD_FAILED=1

    # If the download failed, restore our back-ups, clean-up, and exit
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text "ERROR: Download for Python to path: '${dl_output}' failed!"
      restore_dir "${UBIRD_PYENV_DIR}"
      restore_dir "${UBIRD_PYTHON_DIR}"
      restore_dir "${UBIRD_UV_CACHE}"
      restore_dir "${UBIRD_UV_PYTHON}"
      restore_dir "${UBIRD_UV_LOCAL}/python-cache"
      "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp"
      exit 1
    elif [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
      echo_green_text "SUCCESS: Downloaded Python to path: '${dl_output}'!"

      echo_red_text 'Installing Python...'
      "${UBIRD_UV}" python install "${UBIRD_PYTHON_VERSION}" || local UBIRD_PYTHON_INSTALL_FAILED=1

      # If the install failed, restore our back-ups, clean-up, and exit
      if [[ "${UBIRD_PYTHON_INSTALL_FAILED}" == 1 ]]; then
        echo_red_text "ERROR: Unable to install Python from path: '${dl_output}'!"
        restore_dir "${UBIRD_PYENV_DIR}"
        restore_dir "${UBIRD_PYTHON_DIR}"
        restore_dir "${UBIRD_UV_CACHE}"
        restore_dir "${UBIRD_UV_PYTHON}"
        restore_dir "${UBIRD_UV_LOCAL}/python-cache"
        "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp"
        exit 1
      fi

      echo_red_text "Creating Python environment at path: '${UBIRD_PYENV_DIR}'..."
      "${UBIRD_UV}" venv "${UBIRD_PYENV_DIR}" || local UBIRD_PYENV_FAILED=1

      # If the Python env set-up failed, restore our back-up, clean-up, and exit
      if [[ "${UBIRD_PYENV_FAILED}" == 1 ]]; then
        echo_red_text "ERROR: Unable to set-up Python environment at path: '${UBIRD_PYENV_DIR}'!"
        restore_dir "${UBIRD_PYENV_DIR}"
        "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp"
        exit 1
      else
        echo_green_text "SUCCESS: Set-up Python environment at path: '${UBIRD_PYENV_DIR}'!"
      fi
    fi
  fi
}

# Get shellcheck
function get_shellcheck() {
  # Ensure we have `UBIRD_SHELLCHECK_VERSION`
  if [[ -z "${UBIRD_SHELLCHECK_VERSION+x}" ]] || [[ "${UBIRD_SHELLCHECK_VERSION}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_SHELLCHECK_VERSION' is missing!"
    exit 1
  fi

  # Base download URL
  local -r base_url="https://github.com/koalaman/shellcheck/releases/download/${UBIRD_SHELLCHECK_VERSION}"

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    echo_red_text 'Downloading shellcheck (Linux - ARM64)...'
    download_file "${base_url}/shellcheck-${UBIRD_SHELLCHECK_VERSION}.linux.aarch64.tar.xz" "${UBIRD_SHELLCHECK_DIR}" "${UBIRD_SHELLCHECK_SHA512SUM_LINUX_ARM64}"

    echo_red_text 'Downloading shellcheck (Linux - x86_64)...'
    download_file "${base_url}/shellcheck-${UBIRD_SHELLCHECK_VERSION}.linux.x86_64.tar.xz" "${UBIRD_SHELLCHECK_DIR}" "${UBIRD_SHELLCHECK_SHA512SUM_LINUX_X86_64}"

    echo_red_text 'Downloading shellcheck (OS X - ARM64)...'
    download_file "${base_url}/shellcheck-${UBIRD_SHELLCHECK_VERSION}.darwin.aarch64.tar.xz" "${UBIRD_SHELLCHECK_DIR}" "${UBIRD_SHELLCHECK_SHA512SUM_OSX_ARM64}"

    echo_red_text 'Downloading shellcheck (OS X - x86_64)...'
    download_file "${base_url}/shellcheck-${UBIRD_SHELLCHECK_VERSION}.darwin.x86_64.tar.xz" "${UBIRD_SHELLCHECK_DIR}" "${UBIRD_SHELLCHECK_SHA512SUM_OSX_X86_64}"
  else
    # Set our platform
    if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
      local -r UBIRD_SHELLCHECK_PLATFORM='darwin'
    else
      local -r UBIRD_SHELLCHECK_PLATFORM='linux'
    fi

    # Set our platform architecture
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      local -r UBIRD_SHELLCHECK_ARCH='aarch64'
    else
      local -r UBIRD_SHELLCHECK_ARCH='x86_64'
    fi

    # Set our checksum to verify
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_SHELLCHECK_SHA512SUM="${UBIRD_SHELLCHECK_SHA512SUM_OSX_ARM64}"
      else
        local -r UBIRD_SHELLCHECK_SHA512SUM="${UBIRD_SHELLCHECK_SHA512SUM_LINUX_ARM64}"
      fi
    else
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_SHELLCHECK_SHA512SUM="${UBIRD_SHELLCHECK_SHA512SUM_OSX_X86_64}"
      else
        local -r UBIRD_SHELLCHECK_SHA512SUM="${UBIRD_SHELLCHECK_SHA512SUM_LINUX_X86_64}"
      fi
    fi

    echo_red_text "Downloading shellcheck to path: '${UBIRD_SHELLCHECK_DIR}'..."
    download_and_extract "${base_url}/shellcheck-${UBIRD_SHELLCHECK_VERSION}.${UBIRD_SHELLCHECK_PLATFORM}.${UBIRD_SHELLCHECK_ARCH}.tar.xz" "${UBIRD_SHELLCHECK_DIR}" "${UBIRD_SHELLCHECK_SHA512SUM}"

    if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
      # Set-up the linting pre-commit hook
      if [[ "${UBIRD_CI}" != 1 ]] && [[ -x "${UBIRD_GIT}" ]] && [[ ! -f "${UBIRD_BUILD}/set-hook" ]]; then
        /bin/bash "${UBIRD_SCRIPTS}/lint-hook.sh"
      fi

      echo_green_text "SUCCESS: Set-up shellcheck at path: '${UBIRD_SHELLCHECK}'!"
    fi
  fi
}

# Get shfmt
function get_shfmt() {
  # Ensure we have `UBIRD_SHFMT_VERSION`
  if [[ -z "${UBIRD_SHFMT_VERSION+x}" ]] || [[ "${UBIRD_SHFMT_VERSION}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_SHFMT_VERSION' is missing!"
    exit 1
  fi

  # If all we're doing is updating the checksum, we don't care about existing installations
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    # Ensure we have chmod
    verify_exec "${UBIRD_CHMOD}" 'UBIRD_CHMOD' || exit 1
  fi

  # Base download URL
  local -r base_url="https://github.com/mvdan/sh/releases/download/${UBIRD_SHFMT_VERSION}"

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    echo_red_text 'Downloading shfmt (Linux - ARM64)...'
    download_file "${base_url}/shfmt_${UBIRD_SHFMT_VERSION}_linux_arm64" "${UBIRD_SHFMT}" "${UBIRD_SHFMT_SHA512SUM_LINUX_ARM64}"

    echo_red_text 'Downloading shfmt (Linux - x86_64)...'
    download_file "${base_url}/shfmt_${UBIRD_SHFMT_VERSION}_linux_amd64" "${UBIRD_SHFMT}" "${UBIRD_SHFMT_SHA512SUM_LINUX_X86_64}"

    echo_red_text 'Downloading shfmt (OS X - ARM64)...'
    download_file "${base_url}/shfmt_${UBIRD_SHFMT_VERSION}_darwin_arm64" "${UBIRD_SHFMT}" "${UBIRD_SHFMT_SHA512SUM_OSX_ARM64}"

    echo_red_text 'Downloading shfmt (OS X - x86_64)...'
    download_file "${base_url}/shfmt_${UBIRD_SHFMT_VERSION}_darwin_amd64" "${UBIRD_SHFMT}" "${UBIRD_SHFMT_SHA512SUM_OSX_X86_64}"
  else
    # Set our platform
    if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
      local -r UBIRD_SHFMT_PLATFORM='darwin'
    else
      local -r UBIRD_SHFMT_PLATFORM='linux'
    fi

    # Set our platform architecture
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      local -r UBIRD_SHFMT_ARCH='arm64'
    else
      local -r UBIRD_SHFMT_ARCH='amd64'
    fi

    # Set our checksum to verify
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_SHFMT_SHA512SUM="${UBIRD_SHFMT_SHA512SUM_OSX_ARM64}"
      else
        local -r UBIRD_SHFMT_SHA512SUM="${UBIRD_SHFMT_SHA512SUM_LINUX_ARM64}"
      fi
    else
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_SHFMT_SHA512SUM="${UBIRD_SHFMT_SHA512SUM_OSX_X86_64}"
      else
        local -r UBIRD_SHFMT_SHA512SUM="${UBIRD_SHFMT_SHA512SUM_LINUX_X86_64}"
      fi
    fi

    echo_red_text "Downloading shfmt to path: '${UBIRD_SHFMT}'..."
    download_file "${base_url}/shfmt_${UBIRD_SHFMT_VERSION}_${UBIRD_SHFMT_PLATFORM}_${UBIRD_SHFMT_ARCH}" "${UBIRD_SHFMT}" "${UBIRD_SHFMT_SHA512SUM}"

    if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
      "${UBIRD_CHMOD}" +x "${UBIRD_SHFMT}"

      # Set-up the linting pre-commit hook
      if [[ "${UBIRD_CI}" != 1 ]] && [[ -x "${UBIRD_GIT}" ]] && [[ ! -f "${UBIRD_BUILD}/set-hook" ]]; then
        /bin/bash "${UBIRD_SCRIPTS}/lint-hook.sh"
      fi

      echo_green_text "SUCCESS: Set-up shfmt at path: '${UBIRD_SHFMT}'!"
    fi
  fi
}

# Get uBlock Origin
function get_ublock() {
  # Ensure we have `UBIRD_UBLOCK_COMMIT`
  if [[ -z "${UBIRD_UBLOCK_COMMIT+x}" ]] || [[ "${UBIRD_UBLOCK_COMMIT}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UBLOCK_COMMIT' is missing!"
    exit 1
  fi

  # Ensure we have `UBIRD_UBLOCK_SHA512SUM`
  if [[ -z "${UBIRD_UBLOCK_SHA512SUM+x}" ]] || [[ "${UBIRD_UBLOCK_SHA512SUM}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UBLOCK_SHA512SUM' is missing!"
    exit 1
  fi

  echo_red_text "Downloading uBlock Origin to path: '${UBIRD_UBO}'..."
  download_and_extract "https://github.com/gorhill/uBlock/archive/${UBIRD_UBLOCK_COMMIT}.tar.gz" "${UBIRD_UBO}" "${UBIRD_UBLOCK_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uBlock Origin at path: '${UBIRD_UBO}'!"
  fi
}

# Get uAssets (main)
function get_uassets_main() {
  # Ensure we have `UBIRD_UASSETS_MAIN_COMMIT`
  if [[ -z "${UBIRD_UASSETS_MAIN_COMMIT+x}" ]] || [[ "${UBIRD_UASSETS_MAIN_COMMIT}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UASSETS_MAIN_COMMIT' is missing!"
    exit 1
  fi

  # Ensure we have `UBIRD_UASSETS_MAIN_SHA512SUM`
  if [[ -z "${UBIRD_UASSETS_MAIN_SHA512SUM+x}" ]] || [[ "${UBIRD_UASSETS_MAIN_SHA512SUM}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UASSETS_MAIN_SHA512SUM' is missing!"
    exit 1
  fi

  echo_red_text "Downloading uAssets (main) to path: '${UBIRD_UASSETS_MAIN}'..."
  download_and_extract "https://github.com/uBlockOrigin/uAssets/archive/${UBIRD_UASSETS_MAIN_COMMIT}.tar.gz" "${UBIRD_UASSETS_MAIN}" "${UBIRD_UASSETS_MAIN_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uAssets (main) at path: '${UBIRD_UASSETS_MAIN}'!"
  fi
}

# Get uAssets (prod)
function get_uassets_prod() {
  # Ensure we have `UBIRD_UASSETS_PROD_COMMIT`
  if [[ -z "${UBIRD_UASSETS_PROD_COMMIT+x}" ]] || [[ "${UBIRD_UASSETS_PROD_COMMIT}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UASSETS_PROD_COMMIT' is missing!"
    exit 1
  fi

  # Ensure we have `UBIRD_UASSETS_PROD_SHA512SUM`
  if [[ -z "${UBIRD_UASSETS_PROD_SHA512SUM+x}" ]] || [[ "${UBIRD_UASSETS_PROD_SHA512SUM}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UASSETS_PROD_SHA512SUM' is missing!"
    exit 1
  fi

  echo_red_text "Downloading uAssets (prod) to path: '${UBIRD_UASSETS_PROD}'..."
  download_and_extract "https://github.com/uBlockOrigin/uAssets/archive/${UBIRD_UASSETS_PROD_COMMIT}.tar.gz" "${UBIRD_UASSETS_PROD}" "${UBIRD_UASSETS_PROD_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uAssets (prod) at path: '${UBIRD_UASSETS_PROD}'!"
  fi
}

# Get + set-up uv
function get_uv() {
  # Ensure we have `UBIRD_UV_VERSION`
  if [[ -z "${UBIRD_UV_VERSION+x}" ]] || [[ "${UBIRD_UV_VERSION}" == "" ]]; then
    echo_red_text "ERROR: 'UBIRD_UV_VERSION' is missing!"
    exit 1
  fi

  # If all we're doing is updating the checksum, we don't care about existing installations
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    # Ensure we have rm
    verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

    if [[ -d "${UBIRD_UV_DIR}" ]]; then
      echo_red_text "Found existing installation at path: '${PHOENIX_UV_DIR}'!"
      echo 'Continuing will remove this installation and related data.'
      read -p "Do you still want to continue? [y/N] " -n 1 -r
      echo
      if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
        # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our directories
        backup_dir "${UBIRD_UV_DIR}"
        backup_dir "${UBIRD_UV_LOCAL}"
      else
        return 0
      fi
    fi
  fi

  # Base download URL
  local -r base_url="https://github.com/astral-sh/uv/releases/download/${UBIRD_UV_VERSION}"

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    echo_red_text 'Downloading uv (Linux - ARM64)...'
    download_file "${base_url}/uv-aarch64-unknown-linux-gnu.tar.gz" "${UBIRD_EXTERNAL}/temp/uv-checksum-update-linux-arm64.tar.gz" "${UBIRD_UV_SHA512SUM_LINUX_ARM64}"

    echo_red_text 'Downloading uv (Linux - x86_64)...'
    download_file "${base_url}/uv-x86_64-unknown-linux-gnu.tar.gz" "${UBIRD_EXTERNAL}/temp/uv-checksum-update-linux-x86_64.tar.gz" "${UBIRD_UV_SHA512SUM_LINUX_X86_64}"

    echo_red_text 'Downloading uv (OS X - ARM64)...'
    download_file "${base_url}/uv-aarch64-apple-darwin.tar.gz" "${UBIRD_EXTERNAL}/temp/uv-checksum-update-osx-arm64.tar.gz" "${UBIRD_UV_SHA512SUM_OSX_ARM64}"

    echo_red_text 'Downloading uv (OS X - x86_64)...'
    download_file "${base_url}/uv-x86_64-apple-darwin.tar.gz" "${UBIRD_EXTERNAL}/temp/uv-checksum-update-osx-x86_64.tar.gz" "${UBIRD_UV_SHA512SUM_OSX_X86_64}"
  else
    # Set our platform
    if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
      local -r UBIRD_UV_PLATFORM='apple-darwin'
    else
      local -r UBIRD_UV_PLATFORM='unknown-linux-gnu'
    fi

    # Set our platform architecture
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      local -r UBIRD_UV_ARCH='aarch64'
    else
      local -r UBIRD_UV_ARCH='x86_64'
    fi

    # Set our checksum to verify
    if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_UV_SHA512SUM="${UBIRD_UV_SHA512SUM_OSX_ARM64}"
      else
        local -r UBIRD_UV_SHA512SUM="${UBIRD_UV_SHA512SUM_LINUX_ARM64}"
      fi
    else
      if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
        local -r UBIRD_UV_SHA512SUM="${UBIRD_UV_SHA512SUM_OSX_X86_64}"
      else
        local -r UBIRD_UV_SHA512SUM="${UBIRD_UV_SHA512SUM_LINUX_X86_64}"
      fi
    fi

    # Tell `download` to return instead of exit upon an error
    UBIRD_DOWNLOAD_EXIT=0

    # By default, we know the download hasn't failed...
    local UBIRD_DOWNLOAD_FAILED=0

    echo_red_text "Downloading uv to path: '${UBIRD_UV_DIR}'..."
    download_and_extract "${base_url}/uv-${UBIRD_UV_ARCH}-${UBIRD_UV_PLATFORM}.tar.gz" "${UBIRD_UV_DIR}" "${UBIRD_UV_SHA512SUM}" || local UBIRD_DOWNLOAD_FAILED=1

    # If the download failed, restore our back-up, clean-up, and exit
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text "ERROR: Download for uv to path: '${UBIRD_UV_DIR}' failed!"
      restore_dir "${UBIRD_UV_DIR}"
      restore_dir "${UBIRD_UV_LOCAL}"
      "${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp"
      exit 1
    elif [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
      echo_green_text "SUCCESS: Set-up uv at path: '${UBIRD_UV}'!"
    fi
  fi
}

# Clean-up
"${UBIRD_RM}" -rf "${UBIRD_DOWNLOADS}"
"${UBIRD_RM}" -rf "${UBIRD_EXTERNAL}/temp"

# This needs to run before we get Python
if [[ "${UBIRD_GET_SOURCE_UV}" == 1 ]]; then
  get_uv
fi

if [[ "${UBIRD_GET_SOURCE_PYTHON}" == 1 ]]; then
  get_python
fi

if [[ "${UBIRD_GET_SOURCE_SHELLCHECK}" == 1 ]]; then
  get_shellcheck
fi

if [[ "${UBIRD_GET_SOURCE_SHFMT}" == 1 ]]; then
  get_shfmt
fi

if [[ "${UBIRD_GET_SOURCE_UASSETS_MAIN}" == 1 ]]; then
  get_uassets_main
fi

if [[ "${UBIRD_GET_SOURCE_UASSETS_PROD}" == 1 ]]; then
  get_uassets_prod
fi

if [[ "${UBIRD_GET_SOURCE_UBLOCK}" == 1 ]]; then
  get_ublock
fi
