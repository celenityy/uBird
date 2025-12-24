#!/bin/bash

set -eo pipefail

source "$(dirname $0)/env_local.sh"

# Include version info
source "$rootdir/scripts/versions.sh"

# If variables are defined with a custom `env_override.sh`, let's use those
if [[ -f "$(dirname $0)/env_override.sh" ]]; then
    source "$(dirname $0)/env_override.sh"
fi

if [[ -z "$UBIRD_ADDON_ID" ]]; then
    echo "\$UBIRD_ADDON_ID is not set! Aborting..."
    exit 1
fi

if [[ -z "$UBIRD_UPDATE_URL" ]]; then
    echo "\$UBIRD_UPDATE_URL is not set! Aborting..."
    exit 1
fi

if [[ -z "$UBIRD_VERSION" ]]; then
    echo "\$UBIRD_VERSION is not set! Aborting..."
    exit 1
fi

# Check patch files
source "$rootdir/scripts/patches.sh"

pushd "$ublock_origin"

if ! check_patches; then
    echo "Patch validation failed. Please check the patch files and try again."
    exit 1
fi

# Apply patches
apply_patches

# Replace Add-on ID
$SED -i -e "s|\"id\": \".*\"|\"id\": \""$UBIRD_ADDON_ID"\"|g" platform/thunderbird/manifest.json
$SED -i -e "s|uBlock0@raymondhill.net|$UBIRD_ADDON_ID|g" platform/thunderbird/manifest.json

# Set update URL
## (Run scripts/update_ubird.sh to update updates.json)
$SED -i "s|{UBIRD_UPDATE_URL}|$UBIRD_UPDATE_URL|" platform/thunderbird/manifest.json

# Create uBird...
bash tools/make-thunderbird.sh all

popd

# Copy build output
mkdir -vp "$outputdir"
cp -vrf "$ublock_origin/dist/build/uBlock0.thunderbird.xpi" "$outputdir/uBird_$UBIRD_VERSION.xpi"
cp -vf "$outputdir/uBird_$UBIRD_VERSION.xpi" "$outputdir/uBird_latest.xpi"
