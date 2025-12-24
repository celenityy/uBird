#!/bin/bash

set -eo pipefail

source "$(dirname $0)/env_local.sh"

# Include version info
source "$rootdir/scripts/versions.sh"

# If variables are defined with a custom `env_override.sh`, let's use those
if [[ -f "$(dirname $0)/env_override.sh" ]]; then
    source "$(dirname $0)/env_override.sh"
fi

# Update updates.json
cp -vf updates-template.json updates.json

SHA512SUM=$(sha512sum outputs/uBird_$UBIRD_VERSION.xpi | $AWK '{print $1}')
UBIRD_COMMIT=$(git log -1 --format="%H" | tail -n 1)

$SED -i "s|{SHA512SUM}|$SHA512SUM|" updates.json
$SED -i "s|{UBIRD_COMMIT}|$UBIRD_COMMIT|" updates.json
$SED -i "s|{UBIRD_VERSION}|$UBIRD_VERSION|" updates.json
$SED -i "s|{UBLOCK_VERSION}|$UBLOCK_VERSION|" updates.json
