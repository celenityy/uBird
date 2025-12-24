
# Sources

## uBlock Origin
### https://github.com/gorhill/uBlock
### (This commit corresponds to https://github.com/gorhill/uBlock/releases/tag/1.68.0)
UBLOCK_COMMIT="b9833670211d83e72c3a855984a3d544945de1e3"
UBLOCK_VERSION="1.68.0"

# Configuration
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_SH="$ROOTDIR/scripts/env_local.sh"
EXTERNALDIR="$ROOTDIR/external"
OUTPUTDIR="$ROOTDIR/outputs"
UBLOCKDIR="$EXTERNALDIR/uBlock"

# Use GNU Sed on macOS instead of the built-in sed, due to differences in syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
    SED=gsed
else
    SED=sed
fi
