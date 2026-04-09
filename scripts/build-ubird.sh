#!/bin/bash

set -euo pipefail

# Set-up our environment
source $(dirname $0)/env.sh

# Include utilities
source "${UBIRD_UTILS}"

if [[ -z "${UBIRD_FROM_BUILD+x}" ]]; then
    echo_red_text 'ERROR: Do not call build-ubird.sh directly. Instead, use build.sh.' >&1
    exit 1
fi

# Include version info
source "${UBIRD_VERSIONS}"

if [[ -z "${UBIRD_ADDON_ID}" ]]; then
    echo "\${UBIRD_ADDON_ID} is not set! Aborting..."
    exit 1
fi

if [[ -z "${UBIRD_UPDATE_URL}" ]]; then
    echo "\${UBIRD_UPDATE_URL} is not set! Aborting..."
    exit 1
fi

if [[ -z "${UBIRD_VERSION}" ]]; then
    echo "\${UBIRD_VERSION} is not set! Aborting..."
    exit 1
fi

echo_green_text "Preparing to build uBird ${UBIRD_VERSION}"

# Create build directories
mkdir -p "${UBIRD_BUILD}"
mkdir -p "${UBIRD_OUTPUTS}"

# For checking/applying patch files
source "${UBIRD_SCRIPTS}/patches.sh"

if [[ ! -f "${UBIRD_BUILD}/temp-manifest.json" ]]; then
    cp "${UBIRD_UBO}/platform/thunderbird/manifest.json" "${UBIRD_BUILD}/temp-manifest.json"
fi

function prep_check_patches() {
    if [ "${UBIRD_ATN}" == 1 ]; then
        if ! check_patches_atn; then
            echo_red_text "ERROR: Patch validation failed. Please check the patch files and try again."
            exit 1
        fi
    else
        if ! check_patches; then
            echo_red_text "ERROR: Patch validation failed. Please check the patch files and try again."
            exit 1
        fi
    fi
}

function prep_ubird() {
    # uBird
    echo_red_text 'Preparing your build environment...'
    pushd "${UBIRD_UBO}"

    if [[ -f "${UBIRD_UBO}/platform/thunderbird/manifest.json" ]]; then
        rm -f "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    fi

    cp -f "${UBIRD_BUILD}/temp-manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

    # Check patches
    prep_check_patches

    # Apply patches
    if [ "${UBIRD_ATN}" == 1 ]; then
        apply_patches_atn
    else
        apply_patches
    fi

    # Replace Add-on ID
    "${UBIRD_SED}" -i -e "s|\"id\": \".*\"|\"id\": \""${UBIRD_ADDON_ID}"\"|g" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    "${UBIRD_SED}" -i -e "s|uBlock0@raymondhill.net|${UBIRD_ADDON_ID}|g" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

    if [ "${UBIRD_ATN}" == 1 ]; then
        # Set update URL
        ## (Run scripts/update_ubird.sh to update updates.json)
        "${UBIRD_SED}" -i "s|{UBIRD_UPDATE_URL}|${UBIRD_UPDATE_URL}|" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    fi

    popd

    echo_green_text 'SUCCESS: Prepared build environment'
}

function build_ubird() {
    # Begin the build...
    echo_red_text "Building uBird ${UBIRD_VERSION}..."

    pushd "${UBIRD_UBO}"
    bash -x "${UBIRD_UBO}/tools/make-thunderbird.sh" all
    popd
    
    if [ "${UBIRD_ATN}" == 1 ]; then
        local readonly UBIRD_FILE_NAME="uBird_${UBIRD_VERSION}-atn"
    else
        local readonly UBIRD_FILE_NAME="uBird_${UBIRD_VERSION}"
    fi

    cp "${UBIRD_UBO}/dist/build/uBlock0.thunderbird.xpi" "${UBIRD_OUTPUTS}/${UBIRD_FILE_NAME}.xpi"
    echo_green_text "SUCCESS: Built uBird ${UBIRD_VERSION}"
}

# Set uBird version
pushd "${UBIRD_UBO}"
"${UBIRD_SED}" -i "s|${UBLOCK_VERSION}|${UBIRD_VERSION}|" "${UBIRD_UBO}/dist/version"
popd

prep_ubird
build_ubird
