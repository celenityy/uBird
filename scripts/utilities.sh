#!/bin/bash

set -euo pipefail

# Utility functions for frequently performed tasks
# This file MUST NOT contain anything other than function definitions.

function echo_red_text() {
  echo -e "\033[31m$1\033[0m"
}

function echo_green_text() {
  echo -e "\033[32m$1\033[0m"
}

# Set the verbosity of a script
## (From the value of the `UBIRD_VERBOSE` environment variable)
function set_verbosity() {
  if [[ -z "${UBIRD_VERBOSE+x}" ]]; then
    echo_red_text "ERROR: 'UBIRD_VERBOSE' is missing!"
    exit 1
  fi

  if [[ "${UBIRD_VERBOSE}" == 1 ]]; then
    set -x
  else
    set +x
  fi
}
