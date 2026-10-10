#!/bin/bash

# uBird environment variables

set -euo pipefail

# Set `UBIRD_ROOT`
function set_root() {
  # If `UBIRD_ROOT` is already set to a valid directory, we're done
  if [[ -n "${UBIRD_ROOT+x}" ]] && [[ -d "${UBIRD_ROOT}" ]]; then
    readonly UBIRD_ROOT
    return 0
  fi

  # Find dirname
  if [[ -n "${UBIRD_DIRNAME+x}" ]] && [[ -x "${UBIRD_DIRNAME}" ]]; then
    local -r dirname="${UBIRD_DIRNAME}"
  elif [[ -x '/bin/dirname' ]]; then
    local -r dirname='/bin/dirname'
  elif [[ -x '/usr/bin/dirname' ]]; then
    local -r dirname='/usr/bin/dirname'
  else
    if ! command -v dirname > /dev/null 2>&1; then
      echo "ERROR: Missing dirname!" >&2
      exit 1
    fi
    # It isn't a known location, so we sadly have to just fall-back to the PATH
    local -r dirname="$(dirname)"
  fi

  local -r root_txt="$("${dirname}" $0)/root.txt"

  if [[ ! -f "${root_txt}" ]]; then
    readonly UBIRD_ROOT=$(cd "$("${dirname}" "${BASH_SOURCE[0]}")/.." && pwd)
    if [[ -d "${UBIRD_ROOT}" ]]; then
      echo -n "${UBIRD_ROOT}" > "${root_txt}" || exit 1
    else
      echo "ERROR: Unable to find a valid root directory: '${UBIRD_ROOT}'!"
      exit 1
    fi
  else
    # Find cat
    if [[ -n "${UBIRD_CAT+x}" ]] && [[ -x "${UBIRD_CAT}" ]]; then
      local -r cat="${UBIRD_CAT}"
    elif [[ -x '/bin/cat' ]]; then
      local -r cat='/bin/cat'
    elif [[ -x '/usr/bin/cat' ]]; then
      local -r cat='/usr/bin/cat'
    else
      if ! command -v cat > /dev/null 2>&1; then
        echo "ERROR: Missing cat!" >&2
        exit 1
      fi
      # It isn't a known location, so we sadly have to just fall-back to the PATH
      local -r cat="$(cat)"
    fi

    # Find xargs
    if [[ -n "${UBIRD_XARGS+x}" ]] && [[ -x "${UBIRD_XARGS}" ]]; then
      local -r xargs="${UBIRD_XARGS}"
    elif [[ -x '/bin/xargs' ]]; then
      local -r xargs='/bin/xargs'
    elif [[ -x '/usr/bin/xargs' ]]; then
      local -r xargs='/usr/bin/xargs'
    else
      if ! command -v xargs > /dev/null 2>&1; then
        echo "ERROR: Missing xargs!" >&2
        exit 1
      fi
      # It isn't a known location, so we sadly have to just fall-back to the PATH
      local -r xargs="$(xargs)"
    fi

    readonly UBIRD_ROOT=$("${cat}" "${root_txt}" | "${xargs}")

    if [[ ! -d "${UBIRD_ROOT}" ]]; then
      echo "ERROR: Unable to find a valid root directory: '${UBIRD_ROOT}'!"
      exit 1
    fi
  fi
}

# Add an executable to uBird's PATH
## If the executable is not valid, a warning is displayed instead
function add_to_path() {
  function print_usage() {
    echo "Usage: add_to_path '/path/to/PATH' '/path/to/executable' 'executable_env_var' 'executable'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text "ERROR: Please specify the PATH's path!"
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text 'ERROR: Please specify the path to an executable!'
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text "ERROR: Please specify the executable's environment variable!"
    print_usage
    exit 1
  fi

  if [[ -z "${4+x}" ]]; then
    echo_red_text 'ERROR: Please specify the executable name!'
    print_usage
    exit 1
  fi

  # Ensure we have ln
  verify_exec "${UBIRD_LN}" 'UBIRD_LN' || exit 1

  # Ensure we have mkdir
  verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  local -r path="$1"
  local -r exec="$2"
  local -r exec_env="$3"
  local -r exec_name="$4"

  # Create our PATH directory if necessary
  if [[ ! -d "${path}" ]]; then
    "${UBIRD_MKDIR}" -p "${path}"
  fi

  if verify_env "${exec}" "${exec_env}"; then
    # If our target already exists on the path, remove it
    if [[ -f "${path}/${exec_name}" ]]; then
      "${UBIRD_RM}" -f "${path}/${exec_name}"
    fi
    "${UBIRD_LN}" -sf "${exec}" "${path}/${exec_name}"
    echo_green_text "Added '${exec_name}' to PATH (from '${exec_env}')!"
  else
    echo_red_text "WARNING: Unable to add '${exec_name}' to PATH!"
    echo "Please ensure that '${exec_env}' is set to a valid location."
  fi
}

# Add an executable to uBird's full PATH
function add_to_full_path() {
  function print_usage() {
    echo "Usage: add_to_full_path '/path/to/executable' 'executable_env_var' 'executable'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please specify the path to an executable!'
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text "ERROR: Please specify the executable's environment variable!"
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text 'ERROR: Please specify the executable name!'
    print_usage
    exit 1
  fi

  # Ensure we have `UBIRD_PATH`
  verify_env "${UBIRD_PATH}" 'UBIRD_PATH' || exit 1

  local -r exec="$1"
  local -r exec_env="$2"
  local -r exec_name="$3"

  add_to_path "${UBIRD_PATH}" "${exec}" "${exec_env}" "${exec_name}"
}

# Add an executable to uBird's lint PATH
function add_to_lint_path() {
  function print_usage() {
    echo "Usage: add_to_lint_path '/path/to/executable' 'executable_env_var' 'executable'"
  }

  if [[ -z "${1+x}" ]]; then
    echo_red_text 'ERROR: Please specify the path to an executable!'
    print_usage
    exit 1
  fi

  if [[ -z "${2+x}" ]]; then
    echo_red_text "ERROR: Please specify the executable's environment variable!"
    print_usage
    exit 1
  fi

  if [[ -z "${3+x}" ]]; then
    echo_red_text 'ERROR: Please specify the executable name!'
    print_usage
    exit 1
  fi

  # Ensure we have `UBIRD_LINT_PATH`
  verify_env "${UBIRD_LINT_PATH}" 'UBIRD_LINT_PATH' || exit 1

  local -r exec="$1"
  local -r exec_env="$2"
  local -r exec_name="$3"

  add_to_path "${UBIRD_LINT_PATH}" "${exec}" "${exec_env}" "${exec_name}"
}

# Set-up the full uBird PATH
function setup_path() {
  # Ensure we have `UBIRD_PLATFORM`
  verify_env "${UBIRD_PLATFORM}" 'UBIRD_PLATFORM' || exit 1

  add_to_full_path "${UBIRD_AWK}" 'UBIRD_AWK' 'awk'
  add_to_full_path "${UBIRD_AWK}" 'UBIRD_AWK' 'gawk'
  add_to_full_path "${UBIRD_BASENAME}" 'UBIRD_BASENAME' 'basename'
  add_to_full_path "${UBIRD_BASH}" 'UBIRD_BASH' 'bash'
  add_to_full_path "${UBIRD_CAT}" 'UBIRD_CAT' 'cat'
  add_to_full_path "${UBIRD_CHMOD}" 'UBIRD_CHMOD' 'chmod'
  add_to_full_path "${UBIRD_CP}" 'UBIRD_CP' 'cp'
  add_to_full_path "${UBIRD_CURL}" 'UBIRD_CURL' 'curl'
  add_to_full_path "${UBIRD_DATE}" 'UBIRD_DATE' 'date'
  add_to_full_path "${UBIRD_DATE}" 'UBIRD_DATE' 'gdate'
  add_to_full_path "${UBIRD_DIRNAME}" 'UBIRD_DIRNAME' 'dirname'
  add_to_full_path "${UBIRD_FIND}" 'UBIRD_FIND' 'find'
  add_to_full_path "${UBIRD_GIT}" 'UBIRD_GIT' 'git'
  add_to_full_path "${UBIRD_GREP}" 'UBIRD_GREP' 'grep'
  add_to_full_path "${UBIRD_GZIP}" 'UBIRD_GZIP' 'gzip'
  add_to_full_path "${UBIRD_HEAD}" 'UBIRD_HEAD' 'head'
  add_to_full_path "${UBIRD_LN}" 'UBIRD_LN' 'ln'
  add_to_full_path "${UBIRD_LS}" 'UBIRD_LS' 'ls'
  add_to_full_path "${UBIRD_MD5SUM}" 'UBIRD_MD5SUM' 'md5sum'
  add_to_full_path "${UBIRD_MKDIR}" 'UBIRD_MKDIR' 'mkdir'
  add_to_full_path "${UBIRD_MKTEMP}" 'UBIRD_MKTEMP' 'mktemp'
  add_to_full_path "${UBIRD_MV}" 'UBIRD_MV' 'mv'
  add_to_full_path "${UBIRD_PATCH}" 'UBIRD_PATCH' 'gpatch'
  add_to_full_path "${UBIRD_PATCH}" 'UBIRD_PATCH' 'patch'
  add_to_full_path "${UBIRD_PYTHON}" 'UBIRD_PYTHON' 'python'
  add_to_full_path "${UBIRD_PYTHON}" 'UBIRD_PYTHON' 'python3'
  add_to_full_path "${UBIRD_PYTHON}" 'UBIRD_PYTHON' 'python3.14'
  add_to_full_path "${UBIRD_RM}" 'UBIRD_RM' 'rm'
  add_to_full_path "${UBIRD_SED}" 'UBIRD_SED' 'gsed'
  add_to_full_path "${UBIRD_SED}" 'UBIRD_SED' 'sed'
  add_to_full_path "${UBIRD_SH}" 'UBIRD_SH' 'sh'
  add_to_full_path "${UBIRD_SHASUM}" 'UBIRD_SHASUM' 'shasum'
  add_to_full_path "${UBIRD_TAR}" 'UBIRD_TAR' 'gtar'
  add_to_full_path "${UBIRD_TAR}" 'UBIRD_TAR' 'tar'
  add_to_full_path "${UBIRD_TEE}" 'UBIRD_TEE' 'tee'
  add_to_full_path "${UBIRD_TOUCH}" 'UBIRD_TOUCH' 'touch'
  add_to_full_path "${UBIRD_TR}" 'UBIRD_TR' 'tr'
  add_to_full_path "${UBIRD_UNAME}" 'UBIRD_UNAME' 'uname'
  add_to_full_path "${UBIRD_UNZIP}" 'UBIRD_UNZIP' 'unzip'
  add_to_full_path "${UBIRD_UV}" 'UBIRD_UV' 'uv'
  add_to_full_path "${UBIRD_WC}" 'UBIRD_WC' 'wc'
  add_to_full_path "${UBIRD_XARGS}" 'UBIRD_XARGS' 'xargs'
  add_to_full_path "${UBIRD_XZ}" 'UBIRD_XZ' 'xz'
  add_to_full_path "${UBIRD_YQ}" 'UBIRD_YQ' 'yq'
  add_to_full_path "${UBIRD_ZIP}" 'UBIRD_ZIP' 'zip'

  # OS X-specific
  if [[ "${UBIRD_PLATFORM}" == 'darwin' ]]; then
    add_to_full_path "${UBIRD_DOT_CLEAN}" 'UBIRD_DOT_CLEAN' 'dot_clean'
  fi

  PATH="${UBIRD_PATH}"
  export PATH
}

# Set-up a minimal PATH for linting
function setup_lint_path() {
  add_to_lint_path "${UBIRD_BASH}" 'UBIRD_BASH' 'bash'
  add_to_lint_path "${UBIRD_GIT}" 'UBIRD_GIT' 'git'
  add_to_lint_path "${UBIRD_LS}" 'UBIRD_LS' 'ls'
  add_to_lint_path "${UBIRD_SH}" 'UBIRD_SH' 'sh'
  add_to_lint_path "${UBIRD_SHELLCHECK}" 'UBIRD_SHELLCHECK' 'shellcheck'
  add_to_lint_path "${UBIRD_SHFMT}" 'UBIRD_SHFMT' 'shfmt'

  readonly PATH="${UBIRD_LINT_PATH}"
  export PATH
}

# Remove the legacy `env_local.sh`
function clean_env_local() {
  # Ensure we have rm
  verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

  if [[ -f "$(dirname $0)/env_local.sh" ]]; then
    "${UBIRD_RM}" -f "$(dirname $0)/env_local.sh"
  fi
}

# Set-up our environment
function set_env() {
  if [[ -z "${UBIRD_SET_ENVS+x}" ]] || [[ "${UBIRD_SET_ENVS}" != 1 ]]; then
    # Get our root directory
    set_root || exit 1

    # Ensure we have `UBIRD_ROOT`
    if [[ -z "${UBIRD_ROOT+x}" ]] || [[ ! -d "${UBIRD_ROOT}" ]]; then
      echo "ERROR: 'UBIRD_ROOT' is missing or invalid!"
      exit 1
    fi

    # Do not use the system PATH
    unset PATH || exit 1
    hash -r || exit 1

    source "${UBIRD_ROOT}/scripts/env_common.sh" || exit 1

    # Include utilities
    if [[ -z "${UBIRD_UTILS+x}" ]] || [[ ! -f "${UBIRD_UTILS}" ]] || [[ ! -s "${UBIRD_UTILS}" ]]; then
      echo "ERROR: 'UBIRD_UTILS' is missing or invalid!"
      exit 1
    fi
    source "${UBIRD_UTILS}" || exit 1

    # Set-up our PATH
    if [[ -n "${UBIRD_LINTING+x}" ]]; then
      setup_lint_path || exit 1
    else
      setup_path || exit 1
    fi

    # Clean-up the old `env_local.sh` (if necessary)
    clean_env_local
  fi
}

# Set-up our environment
set_env
