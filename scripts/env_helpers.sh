# shellcheck shell=bash

# Set our platform/OS
function set_platform() {
  # Set platform
  unset UBIRD_PLATFORM
  unset UBIRD_PLATFORM_PRETTY

  # First, leverage `PHOENIX_HOST_PLATFORM`
  if [[ -n "${PHOENIX_HOST_PLATFORM+x}" ]]; then
    if [[ "${PHOENIX_HOST_PLATFORM}" == 'android' ]] || [[ "${PHOENIX_HOST_PLATFORM}" == 'linux' ]]; then
      readonly UBIRD_PLATFORM='linux'
    elif [[ "${PHOENIX_HOST_PLATFORM}" == 'osx' ]] || [[ "${PHOENIX_HOST_PLATFORM}" == 'osx-intel' ]]; then
      readonly UBIRD_PLATFORM='darwin'
    elif [[ "${PHOENIX_HOST_PLATFORM}" == 'windows' ]]; then
      readonly UBIRD_PLATFORM='windows'
    fi
  fi

  # Check `OSTYPE`
  if [[ -z "${UBIRD_PLATFORM+x}" ]] && [[ -n "${OSTYPE+x}" ]]; then
    if [[ "${OSTYPE}" == 'cygwin' ]] || [[ "${OSTYPE}" == 'msys' ]] || [[ "${OSTYPE}" == 'win32' ]]; then
      readonly UBIRD_PLATFORM='windows'
    elif [[ "${OSTYPE}" == "darwin"* ]]; then
      readonly UBIRD_PLATFORM='darwin'
    elif [[ "${OSTYPE}" == 'linux-android' ]] || [[ "${OSTYPE}" == 'linux-gnu' ]]; then
      readonly UBIRD_PLATFORM='linux'
    fi
  fi

  # Check `OS`
  if [[ -z "${UBIRD_PLATFORM+x}" ]] && [[ -n "${OS+x}" ]] && [[ "${OS}" == 'Windows_NT' ]]; then
    readonly UBIRD_PLATFORM='windows'
  fi

  # Not much else we can do :(
  if [[ -z "${UBIRD_PLATFORM+x}" ]]; then
    readonly UBIRD_PLATFORM='unknown'
  fi

  if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
    readonly UBIRD_PLATFORM_PRETTY='Darwin'
  elif [[ "${UBIRD_PLATFORM}" == 'linux' ]]; then
    readonly UBIRD_PLATFORM_PRETTY='Linux'
  elif [[ "${UBIRD_PLATFORM}" == 'windows' ]]; then
    readonly UBIRD_PLATFORM_PRETTY='Windows'
  elif [[ "${UBIRD_PLATFORM}" == 'unknown' ]]; then
    readonly UBIRD_PLATFORM_PRETTY='Unknown'
  else
    echo "ERROR: Invalid platform: '${UBIRD_PLATFORM}'!"
    return 1
  fi

  # Set OS
  unset UBIRD_OS
  unset UBIRD_OS_PRETTY

  if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
    readonly UBIRD_OS='osx'
  elif [[ "${UBIRD_PLATFORM}" == 'windows' ]]; then
    readonly UBIRD_OS='windows'
  elif [[ "${UBIRD_PLATFORM}" == 'linux' ]]; then
    # First, we can check for Android with `PHOENIX_HOST_PLATFORM`
    if [[ -n "${PHOENIX_HOST_PLATFORM+x}" ]] && [[ "${PHOENIX_HOST_PLATFORM}" == 'android' ]]; then
      readonly UBIRD_OS='android'
    fi

    # We can also check for Android with `OSTYPE`
    if [[ -z "${UBIRD_OS+x}" ]] && [[ -n "${OSTYPE+x}" ]] && [[ "${OSTYPE}" == 'linux-android' ]]; then
      readonly UBIRD_OS='android'
    fi

    # Otherwise, we fall back to `/etc/os-release`
    if [[ -z "${UBIRD_OS+x}" ]] && [[ -f '/etc/os-release' ]] && [[ -s '/etc/os-release' ]]; then
      source '/etc/os-release'
      if [[ -n "${ID+x}" ]]; then
        readonly UBIRD_OS="${ID+x}"
      fi
    fi
  fi

  # Not much else we can do :(
  if [[ -z "${UBIRD_OS+x}" ]]; then
    readonly UBIRD_OS='unknown'
  fi

  if [[ "${UBIRD_OS}" == 'android' ]]; then
    readonly UBIRD_OS_PRETTY='Android'
  elif [[ "${UBIRD_OS}" == 'fedora' ]]; then
    readonly UBIRD_OS_PRETTY='Fedora'
  elif [[ "${UBIRD_OS}" == 'osx' ]]; then
    readonly UBIRD_OS_PRETTY='OS X'
  elif [[ "${UBIRD_OS}" == 'secureblue' ]]; then
    readonly UBIRD_OS_PRETTY='Secureblue'
  elif [[ "${UBIRD_OS}" == 'ubuntu' ]]; then
    readonly UBIRD_OS_PRETTY='Ubuntu'
  elif [[ "${UBIRD_OS}" == 'windows' ]]; then
    readonly UBIRD_OS_PRETTY='Windows'
  elif [[ "${UBIRD_OS}" == 'unknown' ]]; then
    readonly UBIRD_OS_PRETTY='Unknown'
  elif [[ "${UBIRD_PLATFORM}" == 'linux' ]] && [[ -n "${ID+x}" ]]; then
    readonly UBIRD_OS_PRETTY="${UBIRD_OS}"
  else
    echo "ERROR: Invalid operating system: '${UBIRD_OS}'!"
    return 1
  fi
}

# Set our architecture
function set_arch() {
  unset UBIRD_PLATFORM_ARCH
  unset UBIRD_PLATFORM_ARCH_PRETTY

  # First, if we're on OS X, we can actually try `PHOENIX_HOST_PLATFORM`
  if [[ "${UBIRD_PLATFORM}" == 'darwin' ]] && [[ -n "${PHOENIX_HOST_PLATFORM+x}" ]]; then
    if [[ "${PHOENIX_HOST_PLATFORM}" == 'osx-intel' ]]; then
      readonly UBIRD_PLATFORM_ARCH='x86_64'
    elif [[ "${PHOENIX_HOST_PLATFORM}" == 'osx' ]]; then
      readonly UBIRD_PLATFORM_ARCH='arm64'
    fi
  fi

  if [[ -z "${UBIRD_PLATFORM_ARCH+x}" ]]; then
    # Find uname
    if [[ -n "${UBIRD_UNAME+x}" ]] && [[ -x "${UBIRD_UNAME}" ]]; then
      local -r uname="${UBIRD_UNAME}"
    elif [[ -x '/bin/uname' ]]; then
      local -r uname='/bin/uname'
    elif [[ -x '/usr/bin/uname' ]]; then
      local -r uname='/usr/bin/uname'
    else
      if ! command -v uname > /dev/null 2>&1; then
        echo "ERROR: Missing uname!" >&2
        return 1
      fi
      # It isn't a known location, so we sadly have to just fall-back to the PATH
      local -r uname="$(uname)"
    fi

    # Set architecture
    local -r arch=$("${uname}" -m)
    if [[ "${arch}" == 'aarch64' ]] || [[ "${arch}" == 'aarch64_be' ]] || [[ "${arch}" == 'arm64' ]] || [[ "${arch}" == 'armv8b' ]] ||
      [[ "${arch}" == 'armv8l' ]]; then
      readonly UBIRD_PLATFORM_ARCH='arm64'
    elif [[ "${arch}" == 'amd64' ]] || [[ "${arch}" == 'x86_64' ]] || [[ "${arch}" == 'x86_64-AT386' ]]; then
      readonly UBIRD_PLATFORM_ARCH='x86_64'
    elif [[ "${arch}" == 'armv4t' ]]; then
      readonly UBIRD_PLATFORM_ARCH='armv4'
    elif [[ "${arch}" == 'armv5t' ]] || [[ "${arch}" == 'armv5te' ]]; then
      readonly UBIRD_PLATFORM_ARCH='armv5'
    elif [[ "${arch}" == 'armv6' ]] || [[ "${arch}" == 'armv6j' ]] || [[ "${arch}" == 'armv6k' ]] || [[ "${arch}" == 'armv6kz' ]] ||
      [[ "${arch}" == 'armv6l' ]] || [[ "${arch}" == 'armv6t2' ]] || [[ "${arch}" == 'armv6z' ]] || [[ "${arch}" == 'armv6zk' ]]; then
      readonly UBIRD_PLATFORM_ARCH='armv6'
    elif [[ "${arch}" == 'armv7' ]] || [[ "${arch}" == 'armv7l' ]] || [[ "${arch}" == 'armv7ve' ]]; then
      readonly UBIRD_PLATFORM_ARCH='arm'
    elif [[ "${arch}" == 'i386' ]] || [[ "${arch}" == 'i386-AT38621' ]]; then
      readonly UBIRD_PLATFORM_ARCH='i386'
    elif [[ "${arch}" == 'i486' ]] || [[ "${arch}" == 'i486-AT38621' ]]; then
      readonly UBIRD_PLATFORM_ARCH='i486'
    elif [[ "${arch}" == 'i586' ]] || [[ "${arch}" == 'i586-AT38621' ]]; then
      readonly UBIRD_PLATFORM_ARCH='i586'
    elif [[ "${arch}" == 'i686' ]] || [[ "${arch}" == 'i686-64' ]] || [[ "${arch}" == 'i686-AT386' ]] || [[ "${arch}" == 'i686-AT38621' ]] ||
      [[ "${arch}" == 'i86pc' ]] || [[ "${arch}" == 'x86' ]] || [[ "${arch}" == 'x86pc' ]]; then
      readonly UBIRD_PLATFORM_ARCH='x86'
    elif [[ "${arch}" == 'ppc' ]] || [[ "${arch}" == 'ppcle' ]]; then
      readonly UBIRD_PLATFORM_ARCH='ppc'
    elif [[ "${arch}" == 'ppc64' ]] || [[ "${arch}" == 'ppc64le' ]]; then
      readonly UBIRD_PLATFORM_ARCH='ppc64'
    elif [[ "${arch}" == 'riscv64' ]]; then
      readonly UBIRD_PLATFORM_ARCH='riscv'
    elif [[ "${arch}" == 's390' ]] || [[ "${arch}" == 's390x' ]]; then
      readonly UBIRD_PLATFORM_ARCH='s390x'
    fi
  fi

  # Not much else we can do :(
  if [[ -z "${UBIRD_PLATFORM_ARCH+x}" ]]; then
    readonly UBIRD_PLATFORM_ARCH='unknown'
  fi

  if [[ "${UBIRD_PLATFORM_ARCH}" == 'arm' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='ARM'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'arm64' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='ARM64'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'armv4' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='ARMv4'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'armv5' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='ARMv5'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'armv6' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='ARMv6'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'ppc' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='PPC'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'ppc64' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='PPC64'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'riscv' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='RISC-V'
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'i386' ]] || [[ "${UBIRD_PLATFORM_ARCH}" == 'i486' ]] || [[ "${UBIRD_PLATFORM_ARCH}" == 'i586' ]] ||
    [[ "${UBIRD_PLATFORM_ARCH}" == 's390x' ]] || [[ "${UBIRD_PLATFORM_ARCH}" == 'x86' ]] || [[ "${UBIRD_PLATFORM_ARCH}" == 'x86_64' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY="${UBIRD_PLATFORM_ARCH}"
  elif [[ "${UBIRD_PLATFORM_ARCH}" == 'unknown' ]]; then
    readonly UBIRD_PLATFORM_ARCH_PRETTY='Unknown'
  else
    echo "ERROR: Invalid architecture: '${UBIRD_PLATFORM_ARCH}'!"
    return 1
  fi
}

# Set our platform/OS
set_platform || return 1

# Set our architecture
set_arch || return 1

echo "Detected platform:         '${UBIRD_PLATFORM_PRETTY}'"
echo "Detected operating system: '${UBIRD_OS_PRETTY}'"
echo "Detected architecture:     '${UBIRD_PLATFORM_ARCH_PRETTY}'"
