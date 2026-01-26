
# Set platform
if [[ "${OSTYPE}" == "darwin"* ]]; then
    export UBIRD_PLATFORM='darwin'
else
    export UBIRD_PLATFORM='linux'
fi

# Set OS
if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
    export UBIRD_OS='osx'
elif [[ "${UBIRD_PLATFORM}" == 'linux' ]]; then
    if [[ -f "/etc/os-release" ]]; then
        source /etc/os-release
        if [[ -n "${ID}" ]]; then
            export UBIRD_OS="${ID}"
        else
            export UBIRD_OS='unknown'
        fi
    else
        export UBIRD_OS='unknown'
    fi
else
    export UBIRD_OS='unknown'
fi
