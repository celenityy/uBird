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
    "${UBIRD_SED}" -i "s|${old_checksum}|${new_checksum}|" "${UBIRD_VERSIONS}"
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
    exit 1
  fi

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" == 1 ]]; then
    update_checksum "${expected_checksum}" "${local_checksum}" "${file}" "${checksum_type}"
  elif [[ "${local_checksum}" != "${expected_checksum}" ]]; then
    echo_red_text 'ERROR: Checksum validation failed.'
    echo "Expected ${checksum_type_pretty}:   ${expected_checksum}"
    echo "Actual ${checksum_type_pretty}:     ${local_checksum}"

    # If checksum validation fails, also just remove the file
    rm -f "${file}"

    exit 1
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
  local readonly filepath="$2"

  if [[ "${url}" == "" ]]; then
    echo_red_text "ERROR: URL is required (file: '${filepath}')"
    exit 1
  fi

  if [[ -f "${filepath}" ]]; then
    echo_red_text "${filepath} already exists."
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      echo_red_text "Removing ${filepath}..."
      rm -f "${filepath}"
    else
      return 0
    fi
  fi

  mkdir -vp "$(dirname "${filepath}")"

  echo_red_text "Downloading ${url}..."
  curl ${UBIRD_CURL_FLAGS} --location "${url}" --output "${filepath}"
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
  cp -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}/${top_input_dir}"/ "${target_path}"
  rm -rf "${UBIRD_EXTERNAL}/temp/${temp_repo_name}"
}

function download_and_extract() {
  local readonly repo_name="$1"
  local readonly url="$2"
  local readonly path="$3"
  local readonly expected_sha512sum="$4"

  if [[ -d "${path}" ]]; then
    echo_red_text "'${path}' already exists"
    read -p "Do you want to re-download? [y/N] " -n 1 -r
    echo
    if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
      echo_red_text "Removing ${path}..."
      rm -rf "${path}"
    else
      return 0
    fi
  fi

  if [[ "${url}" =~ \.tar\.xz$ ]]; then
    local readonly extension=".tar.xz"
  elif [[ "${url}" =~ \.tar\.gz$ ]]; then
    local readonly extension=".tar.gz"
  elif [[ "${url}" =~ \.tar\.zst$ ]]; then
    local readonly extension=".tar.zst"
  else
    local readonly extension=".zip"
  fi

  local readonly repo_archive="${UBIRD_DOWNLOADS}/${repo_name}${extension}"

  download "${url}" "${repo_archive}"

  if [[ ! -f "${repo_archive}" ]]; then
    echo_red_text "ERROR: Source archive for ${repo_name} does not exist."
    exit 1
  fi

  # Before extracting, verify SHA512sum...
  validate_checksum "${expected_sha512sum}" "${repo_archive}" 'sha512sum'

  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    echo_red_text "Extracting ${repo_archive}..."
    extract "${repo_archive}" "${path}" "${repo_name}"
    echo
  fi
}

# Get uBlock Origin
function get_ublock() {
  echo_red_text 'Downloading uBlock Origin...'
  download_and_extract 'ublock' "https://github.com/gorhill/uBlock/archive/${UBLOCK_COMMIT}.tar.gz" "${UBIRD_UBO}" "${UBLOCK_SHA512SUM}"
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    echo_green_text "SUCCESS: Set-up uBlock Origin at ${UBIRD_UBO}"
  fi
}

# Get uAssets (main)
function get_uassets_main() {
  echo_red_text 'Downloading uAssets (main)...'
  download_and_extract 'uassets-main' "https://github.com/uBlockOrigin/uAssets/archive/${UASSETS_MAIN_COMMIT}.tar.gz" "${UBIRD_UASSETS_MAIN}" "${UASSETS_MAIN_SHA512SUM}"
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
    echo_green_text "SUCCESS: Set-up uAssets (main) at ${UBIRD_UASSETS_MAIN}"
  fi
}

# Get uAssets (prod)
function get_uassets_prod() {
  echo_red_text 'Downloading uAssets (prod)...'
  download_and_extract 'uassets-prod' "https://github.com/uBlockOrigin/uAssets/archive/${UASSETS_PROD_COMMIT}.tar.gz" "${UBIRD_UASSETS_PROD}" "${UASSETS_PROD_SHA512SUM}"
  if [[ "${UBIRD_GET_SOURCE_CHECKSUM_UPDATE}" != 1 ]]; then
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
