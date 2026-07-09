#!/bin/bash

set -euo pipefail

# Set-up our environment
source $(dirname $0)/env.sh

# Include utilities
source "${UBIRD_UTILS}"

if [[ -z "${UBIRD_FROM_SOURCES+x}" ]]; then
  echo_red_text "ERROR: Do not call get_sources-ubird.sh directly. Instead, use get_sources.sh." >&1
  exit 1
fi

readonly target="$1"
readonly mode="$2"

# Set-up target parameters
UBIRD_GET_SOURCE_UASSETS_MAIN=0
UBIRD_GET_SOURCE_UASSETS_PROD=0
UBIRD_GET_SOURCE_UBLOCK=0

if [[ "${target}" == 'uassets-main' ]]; then
  # Get uAssets (main)
  UBIRD_GET_SOURCE_UASSETS_MAIN=1
elif [[ "${target}" == 'uassets-prod' ]]; then
  # Get uAssets (prod)
  UBIRD_GET_SOURCE_UASSETS_PROD=1
elif [[ "${target}" == 'ublock' ]]; then
  # Get uBlock Origin
  UBIRD_GET_SOURCE_UBLOCK=1
elif [[ "${target}" == 'all' ]]; then
  # If no argument is specified (or argument is set to "all"), just build everything
  UBIRD_GET_SOURCE_UASSETS_MAIN=1
  UBIRD_GET_SOURCE_UASSETS_PROD=1
  UBIRD_GET_SOURCE_UBLOCK=1
else
  echo_red_text "ERROR: Invalid target: ${target}\n You must enter one of the following:"
  echo 'All:                all (Default)'
  echo 'uAssets (main):     uassets-main'
  echo 'uAssets (prod):     uassets-prod'
  echo 'uBlock Origin:      ublock'
  exit 1
fi
readonly UBIRD_GET_SOURCE_UASSETS_MAIN
readonly UBIRD_GET_SOURCE_UASSETS_PROD
readonly UBIRD_GET_SOURCE_UBLOCK

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
source "${UBIRD_VERSIONS}"

# Back-up (and remove) a file if it exists
function backup_file() {
  local readonly file="$1"
  local readonly file_name="$(basename "${file}")"
  local readonly backup_file="${UBIRD_EXTERNAL}/temp/backup/${file_name}"

  if [[ -f "${file}" ]]; then
    rm -f "${backup_file}"
    mkdir -p "$(dirname "${backup_file}")"
    cp -f "${file}" "${backup_file}"
    rm -f "${file}"
  fi
}

# Back-up (and remove) a directory if it exists
function backup_dir() {
  local readonly dir="$1"
  local readonly dir_name="$(basename "${dir}")"
  local readonly backup_dir="${UBIRD_EXTERNAL}/temp/backup/${dir_name}"

  if [[ -d "${dir}" ]]; then
    rm -rf "${backup_dir}"
    mkdir -p "$(dirname "${backup_dir}")"
    cp -rf "${dir}/" "${backup_dir}"
    rm -rf "${dir}"
  fi
}

# Restore a backed-up file
function restore_file() {
  local readonly file="$1"
  local readonly file_name="$(basename "${file}")"
  local readonly backed_up_file="${UBIRD_EXTERNAL}/temp/backup/${file_name}"

  if [[ -f "${backed_up_file}" ]]; then
    rm -f "${file}"
    mkdir -p "$(dirname "${file}")"
    cp -f "${backed_up_file}" "${file}"
    rm -f "${backed_up_file}"
  fi
}

# Restore a backed-up directory
function restore_dir() {
  local readonly dir="$1"
  local readonly dir_name="$(basename "${dir}")"
  local readonly backed_up_dir="${UBIRD_EXTERNAL}/temp/backup/${dir_name}"

  if [[ -d "${backed_up_dir}" ]]; then
    rm -rf "${dir}"
    mkdir -p "$(dirname "${dir}")"
    cp -rf "${backed_up_dir}/" "${dir}"
    rm -rf "${backed_up_dir}"
  fi
}

# Function to automate updating checksums of dependencies
function update_checksum() {
  local readonly old_checksum="$1"
  local readonly new_checksum="$2"
  local readonly file="$3"
  local readonly checksum_type="$4"

  if [[ "${checksum_type}" == 'md5sum' ]]; then
    local readonly checksum_type_pretty='MD5sum'
  elif [[ "${checksum_type}" == 'sha1sum' ]]; then
    local readonly checksum_type_pretty='SHA1sum'
  elif [[ "${checksum_type}" == 'sha256sum' ]]; then
    local readonly checksum_type_pretty='SHA256sum'
  elif [[ "${checksum_type}" == 'sha512sum' ]]; then
    local readonly checksum_type_pretty='SHA512sum'
  else
    echo_red_text 'ERROR: Unknown checksum type.'
    exit 1
  fi

  if [[ "${old_checksum}" == "${new_checksum}" ]]; then
    echo_red_text 'Checksums match. Skipping...'
    echo "Old checksum:  ${old_checksum}"
    echo "New checksum:  ${new_checksum}"
  else
    echo_red_text "Updating ${checksum_type_pretty} for ${file}..."
    "${UBIRD_SED}" -i "s|'${old_checksum}'|'${new_checksum}'|" "${UBIRD_VERSIONS}"
    echo_green_text "SUCCESS: Updated ${checksum_type_pretty} for ${file}"
  fi
}

function validate_checksum() {
  local readonly expected_checksum="$1"
  local readonly file="$2"
  local readonly checksum_type="$3"

  if [[ "${checksum_type}" == 'md5sum' ]]; then
    local readonly checksum_type_pretty='MD5sum'
    local readonly local_checksum=$(md5sum "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha1sum' ]]; then
    local readonly checksum_type_pretty='SHA1sum'
    local readonly local_checksum=$(sha1sum "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha256sum' ]]; then
    local readonly checksum_type_pretty='SHA256sum'
    local readonly local_checksum=$(sha256sum "${file}" | "${UBIRD_AWK}" '{print $1}')
  elif [[ "${checksum_type}" == 'sha512sum' ]]; then
    local readonly checksum_type_pretty='SHA512sum'
    local readonly local_checksum=$(sha512sum "${file}" | "${UBIRD_AWK}" '{print $1}')
  else
    echo_red_text 'ERROR: Unknown checksum type.'
    return 1
  fi

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    update_checksum "${expected_checksum}" "${local_checksum}" "${file}" "${checksum_type}"
  elif [[ "${local_checksum}" != "${expected_checksum}" ]]; then
    echo_red_text 'ERROR: Checksum validation failed.'
    echo "Expected ${checksum_type_pretty}:   ${expected_checksum}"
    echo "Actual ${checksum_type_pretty}:     ${local_checksum}"

    # If checksum validation fails, also just remove the file
    rm -f "${file}"

    return 1
  else
    echo_green_text 'SUCCESS: Checksum validated.'
    echo "${checksum_type_pretty}: ${local_checksum}"
  fi
}

function clone_repo() {
  local readonly url="$1"
  local readonly path="$2"
  local readonly revision="$3"

  if [[ "${url}" == "" ]]; then
    echo_red_text "ERROR: URL missing for clone"
    exit 1
  fi

  if [[ "${path}" == "" ]]; then
    echo_red_text "ERROR: Path is required for cloning '${url}'"
    exit 1
  fi

  if [[ "${revision}" == "" ]]; then
    echo_red_text "ERROR: Revision is required for cloning '${url}'"
    exit 1
  fi

  if [[ -f "${path}" ]]; then
    echo_red_text "ERROR: '${path}' exists and is not a directory"
    exit 1
  fi

  if [[ -d "${path}" ]]; then
    echo_red_text "'${path}' already exists"
    read -p "Do you want to re-clone this repository? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      echo_red_text "Removing ${path}..."
      rm -rf "${path}"
    else
      return 0
    fi
  fi

  echo_red_text "Cloning ${url}::${revision}..."
  git clone --revision="${revision}" --depth=1 "${url}" "${path}"
}

function download() {
  local readonly url="$1"
  local readonly file_in="$2"
  local readonly file_name=$(basename "${file_in}")
  local readonly expected_sha512sum="$3"

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

  if [[ "${url}" == "" ]]; then
    echo_red_text "ERROR: URL is required (file: '${file_in}')"
    UBIRD_PERFORM_POST_DOWNLOAD=0
    if [[ "${UBIRD_DOWNLOAD_EXIT}" != 1 ]]; then
      unset UBIRD_DOWNLOAD_EXIT
      return 1
    else
      exit 1
    fi
  fi

  # If we're doing a checksum update, we download the file to a separate temporary directory, instead of our standard one
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    rm -rf "${UBIRD_EXTERNAL}/temp/chksm"
    local readonly file="${UBIRD_EXTERNAL}/temp/chksm/${file_name}"
  else
    local readonly file="${file_in}"
  fi

  if [[ -f "${file}" ]]; then
    echo_red_text "${file} already exists."
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our file
      echo_red_text "Removing ${file}..."
      backup_file "${file}"
    else
      unset UBIRD_DOWNLOAD_EXIT
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 0
    fi
  fi

  # By default, we know nothing has failed...
  local UBIRD_CHECKSUM_FAILED=0
  local UBIRD_DOWNLOAD_FAILED=0

  if [[ ! -d "$(dirname "${file}")" ]]; then
    mkdir -vp "$(dirname "${file}")"
    local readonly CREATED_DIR_FOR_DL=1
  else
    local readonly CREATED_DIR_FOR_DL=0
  fi

  echo_red_text "Downloading ${url}..."
  curl ${UBIRD_CURL_FLAGS} --location "${url}" --output "${file}" || local UBIRD_DOWNLOAD_FAILED=1

  # Verify (or update) SHA512sum
  validate_checksum "${expected_sha512sum}" "${file}" 'sha512sum' || local UBIRD_CHECKSUM_FAILED=1

  # If we're just updating the checksum, we're done, so go ahead and exit
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text 'ERROR: Download failed! Exiting...'
      exit 1
    elif [[ "${UBIRD_CHECKSUM_FAILED}" == 1 ]]; then
      echo_red_text 'ERROR: Failed to update checksum! Exiting...'
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
  rm -f "${UBIRD_EXTERNAL}/temp/backup/${file_name}"
  rm -rf "${UBIRD_EXTERNAL}/temp/chksm"

  # If the download (or checksum validation) failed, exit
  if [[ "${UBIRD_CHECKSUM_FAILED}" == 1 ]] || [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
    # If a directory was created just for this download, remove it
    if [[ "${CREATED_DIR_FOR_DL}" == 1 ]]; then
      rm -rf "$(dirname "${file}")"
    fi
    if [[ "${UBIRD_DOWNLOAD_EXIT}" != 1 ]]; then
      unset UBIRD_DOWNLOAD_EXIT
      return 1
    else
      echo_red_text 'ERROR: Download failed! Exiting...'
      exit 1
    fi
  fi
}

# Extract archives
function extract() {
  local readonly archive_path="$1"
  local readonly target_path="$2"
  local readonly temp_repo_name="$3"

  if [[ ! -f "${archive_path}" ]]; then
    echo_red_text "ERROR: Archive '${archive_path}' does not exist!"
  fi

  # If our temporary directory for extraction already exists, delete it
  if [[ -d "${UBIRD_EXTERNAL}/temp/${temp_repo_name}" ]]; then
    rm -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
  fi

  # Create temporary directory for extraction
  mkdir -p "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"

  # Extract based on file extension
  case "${archive_path}" in
    *.zip)
      unzip -q "${archive_path}" -d "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
      ;;
    *.tar.gz)
      "${UBIRD_TAR}" xzf "${archive_path}" -C "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
      ;;
    *.tar.xz)
      "${UBIRD_TAR}" xJf "${archive_path}" -C "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
      ;;
    *.tar.zst)
      "${UBIRD_TAR}" --zstd -xvf "${archive_path}" -C "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
      ;;
    *)
      echo_red_text "ERROR: Unsupported archive format: ${archive_path}"
      rm -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
      exit 1
      ;;
  esac

  local readonly top_input_dir=$(ls "${UBIRD_EXTERNAL}/temp/${temp_repo_name}")
  cp -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}/${top_input_dir}/" "${target_path}"
  rm -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
}

function download_and_extract() {
  local readonly repo_name="$1"
  local readonly url="$2"
  local readonly path="$3"
  local readonly expected_sha512sum="$4"

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
    echo_red_text "'${path}' already exists"
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      # Back-up (in case something goes wrong - ex. checksum validation fails) and remove our directory
      echo_red_text "Removing ${path}..."
      backup_dir "${path}"
    else
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 0
    fi
  fi

  local readonly extension
  if [[ "${url}" =~ \.tar\.xz$ ]]; then
    local readonly extension=".tar.xz"
  elif [[ "${url}" =~ \.tar\.gz$ ]]; then
    local readonly extension=".tar.gz"
  elif [[ "${url}" =~ \.tar\.zst$ ]]; then
    local readonly extension=".tar.zst"
  else
    local readonly extension=".zip"
  fi

  # Tell `download` to return instead of exit upon an error
  UBIRD_DOWNLOAD_EXIT=0

  # By default, we know the download hasn't failed...
  local UBIRD_DOWNLOAD_FAILED=0

  local readonly repo_archive="${UBIRD_DOWNLOADS}/${repo_name}${extension}"
  download "${url}" "${repo_archive}" "${expected_sha512sum}" || local UBIRD_DOWNLOAD_FAILED=1

  # If we're just updating the checksum, we're done, so go ahead and exit
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
      echo_red_text 'ERROR: Download failed! Exiting...'
      exit 1
    else
      return 0
    fi
  fi

  # If the download failed, restore our back-up (if possible) and exit
  if [[ "${UBIRD_DOWNLOAD_FAILED}" == 1 ]]; then
    restore_dir "${path}"
    if [[ "${repo_name}" == 'uv' ]]; then
      UBIRD_PERFORM_POST_DOWNLOAD=0
      return 1
    else
      echo_red_text 'ERROR: Download failed! Exiting...'
      exit 1
    fi
  fi

  echo_red_text "Extracting ${repo_archive}..."
  extract "${repo_archive}" "${path}" "${repo_name}"

  # Clean-up
  rm -rf "${UBIRD_EXTERNAL}/temp/backup/${repo_name}"
}

# Get uBlock Origin
function get_ublock() {
  echo_red_text 'Downloading uBlock Origin...'
  download_and_extract 'ublock' "https://github.com/gorhill/uBlock/archive/${UBLOCK_COMMIT}.tar.gz" "${UBIRD_UBO}" "${UBLOCK_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uBlock Origin at ${UBIRD_UBO}"
  fi
}

# Get uAssets (main)
function get_uassets_main() {
  echo_red_text 'Downloading uAssets (main)...'
  download_and_extract 'uassets-main' "https://github.com/uBlockOrigin/uAssets/archive/${UASSETS_MAIN_COMMIT}.tar.gz" "${UBIRD_UASSETS_MAIN}" "${UASSETS_MAIN_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uAssets (main) at ${UBIRD_UASSETS_MAIN}"
  fi
}

# Get uAssets (prod)
function get_uassets_prod() {
  echo_red_text 'Downloading uAssets (prod)...'
  download_and_extract 'uassets-prod' "https://github.com/uBlockOrigin/uAssets/archive/${UASSETS_PROD_COMMIT}.tar.gz" "${UBIRD_UASSETS_PROD}" "${UASSETS_PROD_SHA512SUM}"
  if [[ "${UBIRD_PERFORM_POST_DOWNLOAD}" == 1 ]]; then
    echo_green_text "SUCCESS: Set-up uAssets (prod) at ${UBIRD_UASSETS_PROD}"
  fi
}

if [[ "${UBIRD_GET_SOURCE_UASSETS_MAIN}" == 1 ]]; then
  get_uassets_main
fi

if [[ "${UBIRD_GET_SOURCE_UASSETS_PROD}" == 1 ]]; then
  get_uassets_prod
fi

if [[ "${UBIRD_GET_SOURCE_UBLOCK}" == 1 ]]; then
  get_ublock
fi
