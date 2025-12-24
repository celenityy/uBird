#!/bin/bash

set -eo pipefail

source "$(dirname $0)/versions.sh"

# If variables are defined with a custom `env_override.sh`, let's use those
if [[ -f "$(dirname $0)/env_override.sh" ]]; then
    source "$(dirname $0)/env_override.sh"
fi

clone_repo() {
    url="$1"
    path="$2"
    revision="$3"

    if [[ "$url" == "" ]]; then
        echo "URL missing for clone"
        exit 1
    fi

    if [[ "$path" == "" ]]; then
        echo "Path is required for cloning '$url'"
        exit 1
    fi

    if [[ "$revision" == "" ]]; then
        echo "Revision is required for cloning '$url'"
        exit 1
    fi

    if [[ -f "$path" ]]; then
        echo "'$path' exists and is not a directory"
        exit 1
    fi

    if [[ -d "$path" ]]; then
        echo "'$path' already exists"
        read -p "Do you want to re-clone this repository? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            return 0
        fi
    fi

    echo "Cloning $url::$revision"
    git clone --revision="$revision" --depth=1 "$url" "$path"
}

# Clone uBlock Origin
echo "Cloning uBlock Origin..."
clone_repo "https://github.com/gorhill/uBlock.git" "$UBLOCKDIR" "$UBLOCK_COMMIT"

# Clone uAssets
echo "Cloning uAssets..."
pushd "$UBLOCKDIR"
bash tools/pull-assets.sh
popd

# Write env_local.sh
echo "Writing ${ENV_SH}..."
cat > "$ENV_SH" << EOF
export outputdir="$OUTPUTDIR"
export rootdir="$ROOTDIR"
export ublock_origin="$UBLOCKDIR"

source "\$rootdir/scripts/env_common.sh"
EOF
