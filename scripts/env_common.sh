
# Caution: Should not be sourced directly!
# Use 'env_local.sh' instead.

if [[ -z ${UBIRD_ADDON_ID+x} ]]; then
    # By default, use "uBird@celenity.dev" for the add-on ID
    export UBIRD_ADDON_ID="uBird@celenity.dev"
fi

if [[ -z ${UBIRD_UPDATE_URL+x} ]]; then
    # By default, use our GitLab update URL
    export UBIRD_UPDATE_URL="https://gitlab.com/celenityy/uBird/-/raw/main/updates.json"
fi
