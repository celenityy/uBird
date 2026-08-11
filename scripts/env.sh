#!/bin/bash

# uBird environment variables

set -euo pipefail

if [[ ! -f "$(dirname $0)/env_local.sh" ]]; then
  readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  readonly ENV_LOCAL="${ROOT}/scripts/env_local.sh"

  # Write env_local.sh
  echo "Writing ${ENV_LOCAL}..."
  cat > "${ENV_LOCAL}" << EOF
# shellcheck shell=bash
readonly UBIRD_ROOT="${ROOT}"
export UBIRD_ROOT

source "\${UBIRD_ROOT}/scripts/env_common.sh"
EOF
fi

# Set-up the full uBird PATH
function setup_path() {
  "${UBIRD_RM}" -rf "${UBIRD_PATH}"
  "${UBIRD_MKDIR}" -p "${UBIRD_PATH}"

  "${UBIRD_LN}" -sf "${UBIRD_AWK}" "${UBIRD_PATH}/awk"
  "${UBIRD_LN}" -sf "${UBIRD_AWK}" "${UBIRD_PATH}/gawk"
  "${UBIRD_LN}" -sf "${UBIRD_BASENAME}" "${UBIRD_PATH}/basename"
  "${UBIRD_LN}" -sf "${UBIRD_CAT}" "${UBIRD_PATH}/cat"
  "${UBIRD_LN}" -sf "${UBIRD_CHMOD}" "${UBIRD_PATH}/chmod"
  "${UBIRD_LN}" -sf "${UBIRD_CP}" "${UBIRD_PATH}/cp"
  "${UBIRD_LN}" -sf "${UBIRD_CURL}" "${UBIRD_PATH}/curl"
  "${UBIRD_LN}" -sf "${UBIRD_DIRNAME}" "${UBIRD_PATH}/dirname"
  "${UBIRD_LN}" -sf "${UBIRD_GIT}" "${UBIRD_PATH}/git"
  "${UBIRD_LN}" -sf "${UBIRD_GREP}" "${UBIRD_PATH}/grep"
  "${UBIRD_LN}" -sf "${UBIRD_GZIP}" "${UBIRD_PATH}/gzip"
  "${UBIRD_LN}" -sf "${UBIRD_LN}" "${UBIRD_PATH}/ln"
  "${UBIRD_LN}" -sf "${UBIRD_LS}" "${UBIRD_PATH}/ls"
  "${UBIRD_LN}" -sf "${UBIRD_MD5SUM}" "${UBIRD_PATH}/md5sum"
  "${UBIRD_LN}" -sf "${UBIRD_MKDIR}" "${UBIRD_PATH}/mkdir"
  "${UBIRD_LN}" -sf "${UBIRD_MKTEMP}" "${UBIRD_PATH}/mktemp"
  "${UBIRD_LN}" -sf "${UBIRD_MV}" "${UBIRD_PATH}/mv"
  "${UBIRD_LN}" -sf "${UBIRD_PATCH}" "${UBIRD_PATH}/gpatch"
  "${UBIRD_LN}" -sf "${UBIRD_PATCH}" "${UBIRD_PATH}/patch"
  "${UBIRD_LN}" -sf "${UBIRD_PYTHON}" "${UBIRD_PATH}/python"
  "${UBIRD_LN}" -sf "${UBIRD_PYTHON}" "${UBIRD_PATH}/python3"
  "${UBIRD_LN}" -sf "${UBIRD_PYTHON}" "${UBIRD_PATH}/python3.14"
  "${UBIRD_LN}" -sf "${UBIRD_RM}" "${UBIRD_PATH}/rm"
  "${UBIRD_LN}" -sf "${UBIRD_SED}" "${UBIRD_PATH}/gsed"
  "${UBIRD_LN}" -sf "${UBIRD_SED}" "${UBIRD_PATH}/sed"
  "${UBIRD_LN}" -sf "${UBIRD_SHASUM}" "${UBIRD_PATH}/shasum"
  "${UBIRD_LN}" -sf "${UBIRD_TAR}" "${UBIRD_PATH}/gtar"
  "${UBIRD_LN}" -sf "${UBIRD_TAR}" "${UBIRD_PATH}/tar"
  "${UBIRD_LN}" -sf "${UBIRD_TEE}" "${UBIRD_PATH}/tee"
  "${UBIRD_LN}" -sf "${UBIRD_TOUCH}" "${UBIRD_PATH}/touch"
  "${UBIRD_LN}" -sf "${UBIRD_TR}" "${UBIRD_PATH}/tr"
  "${UBIRD_LN}" -sf "${UBIRD_UNAME}" "${UBIRD_PATH}/uname"
  "${UBIRD_LN}" -sf "${UBIRD_UNZIP}" "${UBIRD_PATH}/unzip"
  "${UBIRD_LN}" -sf "${UBIRD_UV}" "${UBIRD_PATH}/uv"
  "${UBIRD_LN}" -sf "${UBIRD_WC}" "${UBIRD_PATH}/wc"
  "${UBIRD_LN}" -sf "${UBIRD_XZ}" "${UBIRD_PATH}/xz"
  "${UBIRD_LN}" -sf "${UBIRD_YQ}" "${UBIRD_PATH}/yq"
  "${UBIRD_LN}" -sf "${UBIRD_ZIP}" "${UBIRD_PATH}/zip"

  "${UBIRD_LN}" -sf '/bin/bash' "${UBIRD_PATH}/bash"

  readonly PATH="${UBIRD_PATH}"
  export PATH
}

# Set-up a minimal PATH for linting
function setup_lint_path() {
  "${UBIRD_RM}" -rf "${UBIRD_LINT_PATH}"
  "${UBIRD_MKDIR}" -p "${UBIRD_LINT_PATH}"

  "${UBIRD_LN}" -sf "${UBIRD_GIT}" "${UBIRD_LINT_PATH}/git"
  "${UBIRD_LN}" -sf "${UBIRD_SHELLCHECK}" "${UBIRD_LINT_PATH}/shellcheck"
  "${UBIRD_LN}" -sf "${UBIRD_SHFMT}" "${UBIRD_LINT_PATH}/shfmt"

  readonly PATH="${UBIRD_LINT_PATH}"
  export PATH
}

if [[ -z "${UBIRD_SET_ENVS+x}" ]]; then
  source "$(dirname $0)/env_local.sh"

  # Set-up our PATH
  if [[ -z "${UBIRD_LINTING+x}" ]]; then
    setup_path
  else
    setup_lint_path
  fi
fi
