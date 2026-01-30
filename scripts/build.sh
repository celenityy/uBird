#!/bin/bash

set -euo pipefail

# Set-up our environment
bash -x $(dirname $0)/env.sh
source $(dirname $0)/env.sh

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

# Check patch files
source "${UBIRD_SCRIPTS}/patches.sh"

pushd "${UBIRD_UBO}"

if ! check_patches; then
    echo "Patch validation failed. Please check the patch files and try again."
    exit 1
fi

# Apply patches
apply_patches

# Set uBird version
"${UBIRD_SED}" -i "s|{UBLOCK_VERSION}|${UBIRD_VERSION}|" "${UBIRD_UBO}/dist/version"

# Replace Add-on ID
"${UBIRD_SED}" -i -e "s|\"id\": \".*\"|\"id\": \""${UBIRD_ADDON_ID}"\"|g" "${UBIRD_UBO}/platform/thunderbird/manifest.json"
"${UBIRD_SED}" -i -e "s|uBlock0@raymondhill.net|${UBIRD_ADDON_ID}|g" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

# Set update URL
## (Run scripts/update_ubird.sh to update updates.json)
"${UBIRD_SED}" -i "s|{UBIRD_UPDATE_URL}|${UBIRD_UPDATE_URL}|" "${UBIRD_UBO}/platform/thunderbird/manifest.json"

# Create uBird...
bash -x "${UBIRD_UBO}/tools/make-thunderbird.sh" all

popd

# Copy build output
mkdir -vp "${UBIRD_OUTPUTS}"
cp -vrf "${UBIRD_UBO}/dist/build/uBlock0.thunderbird.xpi" "${UBIRD_OUTPUTS}/uBird_${UBIRD_VERSION}.xpi"
cp -vf "${UBIRD_OUTPUTS}/uBird_${UBIRD_VERSION}.xpi" "${UBIRD_OUTPUTS}/uBird_latest.xpi"
