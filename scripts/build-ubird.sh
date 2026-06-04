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

readonly target="$1"

# Set-up target parameters
UBIRD_BUILD_ATN=0
UBIRD_BUILD_DIRECT=0

if [[ "${target}" == 'atn' ]]; then
    # Build uBird (ATN)
    UBIRD_BUILD_ATN=1
elif [[ "${target}" == 'direct' ]]; then
    # Build uBird (Self-distribution)
    UBIRD_BUILD_DIRECT=1
elif [[ "${target}" == 'all' ]]; then
    # If no argument is specified (or argument is set to "all"), just build both
    UBIRD_BUILD_ATN=1
    UBIRD_BUILD_DIRECT=1
else
    echo_red_text "ERROR: Invalid target: ${target}\n You must enter one of the following:"
    echo 'uBird (Self-distribution):    direct (Default)'
    echo 'uBird (ATN):                  atn'
    exit 1
fi
readonly UBIRD_BUILD_ATN
readonly UBIRD_BUILD_DIRECT

# Include version info
source "${UBIRD_VERSIONS}"

if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
    if [[ -z "${UBIRD_ATN_ADDON_ID}" ]]; then
        echo_red_text 'ERROR: The UBIRD_ATN_ADDON_ID environment variable is missing! Aborting...'
        exit 1
    fi
fi

if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
    if [[ -z "${UBIRD_ADDON_ID}" ]]; then
        echo_red_text 'ERROR: The UBIRD_ADDON_ID environment variable is missing! Aborting...'
        exit 1
    fi

    if [[ -z "${UBIRD_UPDATE_URL}" ]]; then
        echo_red_text 'ERROR: The UBIRD_UPDATE_URL environment variable is missing! Aborting...'
        exit 1
    fi
fi

if [[ -z "${UBIRD_VERSION}" ]]; then
    echo_red_text 'ERROR: The UBIRD_VERSION environment variable is missing! Aborting...'
    exit 1
fi

if [[ -z "${UBLOCK_VERSION}" ]]; then
    echo_red_text 'ERROR: The UBLOCK_VERSION environment variable is missing! Aborting...'
    exit 1
fi

if [[ -z "${UBIRD_UBO}" ]]; then
    echo_red_text 'ERROR: The UBIRD_UBO environment variable is missing! Aborting...'
    exit 1
fi

if [[ ! -d "${UBIRD_UBO}" ]]; then
    echo_red_text "ERROR: uBlock Origin not found! (${UBIRD_UBO})"
    echo_green_text "Please ensure the UBIRD_UBO environment variable is set to the correct path in which uBlock Origin is located."
    echo_red_text "Aborting..."
    exit 1
fi

if [[ -z "${UBIRD_UASSETS_MAIN}" ]]; then
    echo_red_text 'ERROR: The UBIRD_UASSETS_MAIN environment variable is missing! Aborting...'
    exit 1
fi

if [[ ! -d "${UBIRD_UASSETS_MAIN}" ]]; then
    echo_red_text "ERROR: uAssets (main) not found! (${UBIRD_UASSETS_MAIN})"
    echo_green_text "Please ensure the UBIRD_UASSETS_MAIN environment variable is set to the correct path in which uAssets (main) is located."
    echo_red_text "Aborting..."
    exit 1
fi

if [[ -z "${UBIRD_UASSETS_PROD}" ]]; then
    echo_red_text 'ERROR: The UBIRD_UASSETS_PROD environment variable is missing! Aborting...'
    exit 1
fi

if [[ ! -d "${UBIRD_UASSETS_PROD}" ]]; then
    echo_red_text "ERROR: uAssets (prod) not found! (${UBIRD_UASSETS_PROD})"
    echo_green_text "Please ensure the UBIRD_UASSETS_PROD environment variable is set to the correct path in which uAssets (prod) is located."
    echo_red_text "Aborting..."
    exit 1
fi

echo_green_text "Preparing to build uBird ${UBIRD_VERSION}"

# Create build directories
mkdir -p "${UBIRD_BUILD}"
if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
    mkdir -p "${UBIRD_OUTPUTS}/atn"
fi
if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
    mkdir -p "${UBIRD_OUTPUTS}/direct"
fi

# For checking/applying patch files
source "${UBIRD_SCRIPTS}/patches.sh"

if [[ ! -f "${UBIRD_BUILD}/temp-manifest.json" ]]; then
    cp "${UBIRD_UBO}/platform/thunderbird/manifest.json" "${UBIRD_BUILD}/temp-manifest.json"
fi

function prep_check_patches() {
    if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
        if ! check_patches_atn; then
            echo_red_text "ERROR: Patch validation failed. Please check the patch files and try again."
            exit 1
        fi
    fi
    if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
        if ! check_patches; then
            echo_red_text "ERROR: Patch validation failed. Please check the patch files and try again."
            exit 1
        fi
    fi
}

function set_version() {
    # Set uBird version
    pushd "${UBIRD_UBO}"
    "${UBIRD_SED}" -i "s|${UBLOCK_VERSION}|${UBIRD_VERSION}|" "${UBIRD_UBO}/dist/version"
    popd
}

function prep_ubird() {
    # uBird
    echo_red_text 'Preparing your build environment...'
    pushd "${UBIRD_UBO}"

    if [[ -f "${UBIRD_UBO}/platform/thunderbird/manifest.json" ]]; then
        rm "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    fi

    cp -f "${UBIRD_BUILD}/temp-manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

    if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets" ]]; then
        mkdir -p "${UBIRD_UBO}/dist/build/uAssets"
    fi

    if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets/main" ]]; then
        ln -s "${UBIRD_UASSETS_MAIN}" "${UBIRD_UBO}/dist/build/uAssets/main"
    fi

    if [[ ! -d "${UBIRD_UBO}/dist/build/uAssets/prod" ]]; then
        ln -s "${UBIRD_UASSETS_PROD}" "${UBIRD_UBO}/dist/build/uAssets/prod"
    fi

    # Check patches
    prep_check_patches

    # Apply patches
    if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
        apply_patches_atn
        cp -f "${UBIRD_UBO}/platform/thunderbird/manifest.json" "${UBIRD_OUTPUTS}/atn/manifest.json"
        cp -f "${UBIRD_BUILD}/temp-manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    fi
    if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
        apply_patches
        cp -f "${UBIRD_UBO}/platform/thunderbird/manifest.json" "${UBIRD_OUTPUTS}/direct/manifest.json"
        cp -f "${UBIRD_BUILD}/temp-manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    fi

    if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
        # Set update URL
        "${UBIRD_SED}" -i "s|{UBIRD_UPDATE_URL}|${UBIRD_UPDATE_URL}|" "${UBIRD_OUTPUTS}/direct/manifest.json"
    fi

    # Set add-on ID
    if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
        "${UBIRD_SED}" -i -e "s|\"id\": \".*\"|\"id\": \""${UBIRD_ATN_ADDON_ID}"\"|g" "${UBIRD_OUTPUTS}/atn/manifest.json"
        "${UBIRD_SED}" -i -e "s|uBlock0@raymondhill.net|${UBIRD_ATN_ADDON_ID}|g" "${UBIRD_OUTPUTS}/atn/manifest.json"
    fi
    if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
        "${UBIRD_SED}" -i -e "s|\"id\": \".*\"|\"id\": \""${UBIRD_ADDON_ID}"\"|g" "${UBIRD_OUTPUTS}/direct/manifest.json"
        "${UBIRD_SED}" -i -e "s|uBlock0@raymondhill.net|${UBIRD_ADDON_ID}|g" "${UBIRD_OUTPUTS}/direct/manifest.json"
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

    cp -f "${UBIRD_BUILD}/temp-manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

    echo_green_text "SUCCESS: Built uBird ${UBIRD_VERSION}"
}

function build_ubird_atn() {
    cp -f "${UBIRD_OUTPUTS}/atn/manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    build_ubird
    cp -f "${UBIRD_UBO}/dist/build/uBlock0.thunderbird.xpi" "${UBIRD_OUTPUTS}/ubird-${UBIRD_VERSION}-atn-unsigned.xpi"
}

function build_ubird_direct() {
    cp -f "${UBIRD_OUTPUTS}/direct/manifest.json" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
    build_ubird
    cp -f "${UBIRD_UBO}/dist/build/uBlock0.thunderbird.xpi" "${UBIRD_OUTPUTS}/ubird-${UBIRD_VERSION}-unsigned.xpi"
}

set_version
prep_ubird

if [[ "${UBIRD_BUILD_ATN}" == 1 ]]; then
    build_ubird_atn
fi

if [[ "${UBIRD_BUILD_DIRECT}" == 1 ]]; then
    build_ubird_direct
fi

