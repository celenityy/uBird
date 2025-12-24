
# Caution: Should not be sourced directly!
# Use 'env_local.sh' instead.

if [[ -z ${UBIRD_ADDON_ID+x} ]]; then
    # By default, use "uBird@celenity.dev" for the add-on ID
    export UBIRD_ADDON_ID="uBird@celenity.dev"

    echo "Preparing to build uBlock Origin for Thunderbird..."
fi
