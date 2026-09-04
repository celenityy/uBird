#!/bin/bash

set -euo pipefail

# Set-up our environment
if [[ -z "${UBIRD_SET_ENVS+x}" ]]; then
  /bin/bash $(dirname $0)/env.sh || exit 1
fi
source $(dirname $0)/env.sh || exit 1

# Include utilities
source "${UBIRD_UTILS}" || exit 1

# Ensure we have GNU awk
verify_exec "${UBIRD_AWK}" 'UBIRD_AWK' || exit 1

# Set up target parameters
if [[ -z "${1+x}" ]]; then
  readonly target='all'
else
  readonly target=$(echo "${1}" | "${UBIRD_AWK}" '{print tolower($0)}')
fi

# Build uBird
readonly UBIRD_FROM_BUILD=1
export UBIRD_FROM_BUILD
if [[ "${UBIRD_LOG_BUILD}" == 1 ]]; then
  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  # Ensure we have tee
  verify_exec "${UBIRD_TEE}" 'UBIRD_TEE' || exit 1

  readonly BUILD_LOG_FILE="${UBIRD_LOG_DIR}/build.log"

  # If the log file already exists, remove it
  if [[ -f "${BUILD_LOG_FILE}" ]]; then
    "${UBIRD_RM}" "${BUILD_LOG_FILE}"
  fi

  # Ensure our log directory exists
  "${UBIRD_MKDIR}" -vp "${UBIRD_LOG_DIR}"

  /bin/bash "${UBIRD_SCRIPTS}/build-ubird.sh" "${target}" > >("${UBIRD_TEE}" -a "${BUILD_LOG_FILE}") 2>&1 || exit 1
else
  /bin/bash "${UBIRD_SCRIPTS}/build-ubird.sh" "${target}" || exit 1
fi
