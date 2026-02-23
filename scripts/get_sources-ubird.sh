#!/bin/bash

set -euo pipefail

# Set-up our environment
bash -x $(dirname $0)/env.sh
source $(dirname $0)/env.sh

if [[ -z "${UBIRD_FROM_SOURCES+x}" ]]; then
    echo_red_text "ERROR: Do not call get_sources-ubird.sh directly. Instead, use get_sources.sh." >&1
    exit 1
fi

target="$1"

# Set-up target parameters
UBIRD_GET_SOURCE_UASSETS=0
UBIRD_GET_SOURCE_UBLOCK=0

if [ "${target}" == 'uassets' ]; then
    # Get uAssets
    UBIRD_GET_SOURCE_UASSETS=1
elif [ "${target}" == 'up-ac' ]; then
    # Get uBlock Origin
    UBIRD_GET_SOURCE_UBLOCK=1
else
    # If no argument is specified (or argument is set to "all"), just build everything
    UBIRD_GET_SOURCE_UASSETS=1
    UBIRD_GET_SOURCE_UBLOCK=1
fi

# Include version info
source "${UBIRD_VERSIONS}"

function clone_repo() {
    url="$1"
    path="$2"
    revision="$3"

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

# Get uBlock Origin
function get_ublock() {
    echo_red_text "Cloning uBlock Origin..."
    clone_repo "https://github.com/gorhill/uBlock.git" "${UBIRD_UBO}" "${UBLOCK_COMMIT}"
    echo_green_text "SUCCESS: Set-up uBlock Origin at ${UBIRD_UBO}"
}

# Get uAssets
function get_uassets() {
    if  [[ ! -d "${UBIRD_UBO}" ]]; then
        echo_red_text "ERROR: You tried to get uAssets, but you don't have uBlock Origin set-up yet."
        exit 1
    fi

    if [[ -d "${UBIRD_UBO}/dist/build/uAssets" ]]; then
        echo_red_text "uAssets is already set-up at ${UBIRD_UBO}/dist/build/uAssets"
        read -p "Do you want to re-create it? [y/N] " -n 1 -r
        echo
        if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
            rm -rf "${UBIRD_UBO}/dist/build/uAssets"
        fi
    fi

    echo_red_text "Cloning uAssets..."
    pushd "${UBIRD_UBO}"
    bash -x "${UBIRD_UBO}/tools/pull-assets.sh"
    popd
    echo_green_text "SUCCESS: Set-up uAssets at ${UBIRD_UBO}/dist/build/uAssets"
}

# This needs to run before we get uAssets
if [ "${UBIRD_GET_SOURCE_UBLOCK}" == 1 ]; then
    get_ublock
fi

if [ "${UBIRD_GET_SOURCE_UASSETS}" == 1 ]; then
    get_uassets
fi
