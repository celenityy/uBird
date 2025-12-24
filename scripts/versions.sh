
# Sources

## uBlock Origin
### https://github.com/gorhill/uBlock
### (This commit corresponds to https://github.com/gorhill/uBlock/releases/tag/1.68.0)
UBLOCK_COMMIT="b9833670211d83e72c3a855984a3d544945de1e3"
UBLOCK_VERSION="1.68.0"

UBIRD_VERSION="${UBLOCK_VERSION}"

# Configuration
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_SH="$ROOTDIR/scripts/env_local.sh"
EXTERNALDIR="$ROOTDIR/external"
OUTPUTDIR="$ROOTDIR/outputs"
PATCHDIR="$ROOTDIR/patches"
UBLOCKDIR="$EXTERNALDIR/uBlock"

# Use GNU awk and GNU sed on macOS instead of the built-in awk and sed, due to differences in syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
    AWK=gawk
    SED=gsed
else
    AWK=awk
    SED=sed
fi
