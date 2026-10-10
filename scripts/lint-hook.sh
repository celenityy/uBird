#!/bin/bash

# Script to configure a git pre-commit hook for linting

set -euo pipefail

# Set-up our environment
function setup_env() {
  if [[ -z "${UBIRD_SET_ENVS+x}" ]] || [[ "${UBIRD_SET_ENVS}" != 1 ]]; then
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

    # Set-up our environment
    readonly UBIRD_ENV_SH="$("${dirname}" $0)/env.sh"
    if [[ ! -f "${UBIRD_ENV_SH}" ]] || [[ ! -s "${UBIRD_ENV_SH}" ]]; then
      echo "ERROR: '${UBIRD_ENV_SH}' is invalid!"
      exit 1
    fi
    source "${UBIRD_ENV_SH}" || exit 1
  fi
}

# Set-up our environment
setup_env

# Set verbosity
set_verbosity

# Ensure we have git
verify_exec "${UBIRD_GIT}" 'UBIRD_GIT' || exit 1

# Ensure we have mkdir
verify_exec "${UBIRD_MKDIR}" 'UBIRD_MKDIR' || exit 1

# Ensure we have rm
verify_exec "${UBIRD_RM}" 'UBIRD_RM' || exit 1

# Ensure we have touch
verify_exec "${UBIRD_TOUCH}" 'UBIRD_TOUCH' || exit 1

# Ensure we have `UBIRD_BUILD`
verify_env "${UBIRD_BUILD}" 'UBIRD_BUILD' || exit 1

# Check if the hook has already been set-up
if [[ -f "${UBIRD_BUILD}/set-hook" ]]; then
  echo_red_text 'It looks like the git pre-commit hook has already been set-up!'
  read -p "Are you sure you want to continue? [y/N] " -n 1 -r
  echo
  if [[ "${REPLY}" =~ ^[Nn]$ ]]; then
    exit 0
  else
    "${UBIRD_RM}" -f "${UBIRD_BUILD}/set-hook"
  fi
fi

# Enable the pre-commit hook so shell scripts are linted (shellcheck + shfmt)
# before each commit. CI enforces the same checks, so this is just a fast local
# safeguard (and is bypassable with `git commit --no-verify`).
echo_red_text 'Configuring git pre-commit hook...'
"${UBIRD_GIT}" -C "${UBIRD_ROOT}" config core.hooksPath scripts/git-hooks
echo_green_text 'SUCCESS: Configured git pre-commit hook'

# Indicate that the hook has been set-up
"${UBIRD_MKDIR}" -p "${UBIRD_BUILD}"
"${UBIRD_TOUCH}" "${UBIRD_BUILD}/set-hook"
