#!/bin/bash

set -euo pipefail

# Set-up our environment
bash -x $(dirname $0)/env.sh
source $(dirname $0)/env.sh

# Build uBird
export UBIRD_FROM_BUILD=1
if [ "${UBIRD_LOG_BUILD}" == 1 ]; then
    BUILD_LOG_FILE="${UBIRD_LOG_DIR}/build.log"

    # If the log file already exists, remove it
    if [ -f "${BUILD_LOG_FILE}" ]; then
        rm "${BUILD_LOG_FILE}"
    fi

    # Ensure our log directory exists
    mkdir -vp "${UBIRD_LOG_DIR}"

    bash -x "${UBIRD_SCRIPTS}/build-ubird.sh" > >(tee -a "${BUILD_LOG_FILE}") 2>&1
else
    bash -x "${UBIRD_SCRIPTS}/build-ubird.sh"
fi
