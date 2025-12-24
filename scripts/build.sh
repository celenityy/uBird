#!/bin/bash

set -eo pipefail

source "$(dirname $0)/env_local.sh"

# Include version info
source "$rootdir/scripts/versions.sh"

# If variables are defined with a custom `env_override.sh`, let's use those
if [[ -f "$(dirname $0)/env_override.sh" ]]; then
    source "$(dirname $0)/env_override.sh"
fi

pushd "$ublock_origin"

# Replace Add-on ID
$SED -i -e "s|\"id\": \".*\"|\"id\": \""$UBIRD_ADDON_ID"\"|g" platform/thunderbird/manifest.json
$SED -i -e "s|uBlock0@raymondhill.net|$UBIRD_ADDON_ID|g" platform/thunderbird/manifest.json

# Create uBird...
bash tools/make-thunderbird.sh all

popd

# Copy build output
mkdir -vp "$outputdir"
cp -vrf "$ublock_origin/dist/build/uBlock0.thunderbird.xpi" "$outputdir/uBird_$UBLOCK_VERSION.xpi"
cp -vf "$outputdir/uBird_$UBLOCK_VERSION.xpi" "$outputdir/uBird_latest.xpi"
