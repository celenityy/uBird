# shellcheck shell=bash
# Set platform
if [[ "${OSTYPE}" == "darwin"* ]]; then
  readonly UBIRD_PLATFORM='darwin'
else
  readonly UBIRD_PLATFORM='linux'
fi
export UBIRD_PLATFORM

# Set OS
if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
  readonly UBIRD_OS='osx'
elif [[ "${UBIRD_PLATFORM}" == 'linux' ]]; then
  if [[ -f "/etc/os-release" ]]; then
    source /etc/os-release
    if [[ -n "${ID}" ]]; then
      readonly UBIRD_OS="${ID}"
    else
      readonly UBIRD_OS='unknown'
    fi
  else
    readonly UBIRD_OS='unknown'
  fi
else
  readonly UBIRD_OS='unknown'
fi
export UBIRD_OS

# Set architecture
readonly PLATFORM_ARCH=$(uname -m)
if [[ "${PLATFORM_ARCH}" == 'arm64' ]]; then
  readonly UBIRD_PLATFORM_ARCH='arm64'
else
  readonly UBIRD_PLATFORM_ARCH='x86_64'
fi
export UBIRD_PLATFORM_ARCH
