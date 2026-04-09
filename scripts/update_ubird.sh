#!/bin/bash

set -euo pipefail

# Set-up our environment
if [[ -z "${UBIRD_SET_ENVS+x}" ]]; then
    bash -x $(dirname $0)/env.sh
fi
source $(dirname $0)/env.sh

# Include version info
source "${UBIRD_VERSIONS}"

pushd "${UBIRD_ROOT}"

# Update updates.json
cp -vf "${UBIRD_ROOT}/updates-template.json" "${UBIRD_ROOT}/updates.json"

readonly SHA512SUM=$(sha512sum outputs/uBird_${UBIRD_VERSION}.xpi | ${UBIRD_AWK} '{print $1}')
readonly UBIRD_COMMIT=$(git log -1 --format="%H" | tail -n 1)

"${UBIRD_SED}" -i "s|{SHA512SUM}|${SHA512SUM}|" "${UBIRD_ROOT}/updates.json"
"${UBIRD_SED}" -i "s|{UBIRD_COMMIT}|${UBIRD_COMMIT}|" "${UBIRD_ROOT}/updates.json"
"${UBIRD_SED}" -i "s|{UBIRD_VERSION}|${UBIRD_VERSION}|" "${UBIRD_ROOT}/updates.json"
"${UBIRD_SED}" -i "s|{UBLOCK_VERSION}|${UBLOCK_VERSION}|" "${UBIRD_ROOT}/updates.json"

popd
