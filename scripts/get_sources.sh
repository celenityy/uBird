#!/bin/bash

set -euo pipefail

# Set-up our environment
function setup_env() {
  if [[ -z "${UBIRD_SET_ENVS+x}" ]] || [[ "${UBIRD_SET_ENVS}" != 1 ]]; then
    # Find dirname
    if [[ -n "${UBIRD_DIRNAME+x}" ]] && [[ -x "${UBIRD_DIRNAME}" ]]; then
      local -r dirname="${UBIRD_DIRNAME}"
    elif [[ -x '/bin/dirname' ]]; then
      local -r dirname='/bin/dirname'
    elif [[ -x '/usr/bin/dirname' ]]; then
      local -r dirname='/usr/bin/dirname'
    else
      if ! command -v dirname > /dev/null 2>&1; then
        echo "ERROR: Missing dirname!" >&2
        exit 1
      fi
      # It isn't a known location, so we sadly have to just fall-back to the PATH
      local -r dirname="$(dirname)"
    fi

    # Set-up our environment
    readonly UBIRD_ENV_SH="$("${dirname}" $0)/env.sh"
    if [[ ! -f "${UBIRD_ENV_SH}" ]] || [[ ! -s "${UBIRD_ENV_SH}" ]]; then
      echo "ERROR: '${UBIRD_ENV_SH}' is invalid!"
      exit 1
    fi
    source "${UBIRD_ENV_SH}" || exit 1
  fi
}

# Set-up our environment
setup_env

# Ensure we have GNU awk
verify_exec "${UBIRD_AWK}" 'UBIRD_AWK' || exit 1

# Ensure we have `UBIRD_LOG_SOURCES`
verify_env "${UBIRD_LOG_SOURCES}" 'UBIRD_LOG_SOURCES' || exit 1

# Ensure we have `UBIRD_SCRIPTS`
verify_dir_with_env "${UBIRD_SCRIPTS}" 'UBIRD_SCRIPTS' || exit 1

# Ensure we have our target script
readonly UBIRD_SOURCES_SH="${UBIRD_SCRIPTS}/get_sources-ubird.sh"
verify_file "${UBIRD_SOURCES_SH}" || exit 1

# Set up target parameters
if [[ -z "${1+x}" ]]; then
  readonly source_target='all'
else
  readonly source_target=$(echo "${1}" | "${UBIRD_AWK}" '{print tolower($0)}')
fi

if [[ -z "${2+x}" ]]; then
  readonly mode='download'
else
  readonly mode=$(echo "${2}" | "${UBIRD_AWK}" '{print tolower($0)}')
fi

# Get sources
readonly UBIRD_FROM_SOURCES=1
export UBIRD_FROM_SOURCES
if [[ "${UBIRD_LOG_SOURCES}" == 1 ]]; then
  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  # Ensure we have tee
  verify_exec "${UBIRD_TEE}" 'UBIRD_TEE' || exit 1

  # Ensure we have `UBIRD_LOG_DIR`
  verify_env "${UBIRD_LOG_DIR}" 'UBIRD_LOG_DIR' || exit 1

  readonly SOURCES_LOG_FILE="${UBIRD_LOG_DIR}/get_sources.log"

  # If the log file already exists, remove it
  if [[ -f "${SOURCES_LOG_FILE}" ]]; then
    "${UBIRD_RM}" "${SOURCES_LOG_FILE}"
  fi

  # Ensure our log directory exists
  "${UBIRD_MKDIR}" -vp "${UBIRD_LOG_DIR}"

  source "${UBIRD_SOURCES_SH}" "${source_target}" "${mode}" > >("${UBIRD_TEE}" -a "${SOURCES_LOG_FILE}") 2>&1 || exit 1
else
  source "${UBIRD_SOURCES_SH}" "${source_target}" "${mode}" || exit 1
fi
