#!/bin/bash

set -euo pipefail

# Set-up our environment
if [[ -z "${UBIRD_SET_ENVS+x}" ]]; then
  /bin/bash $(dirname $0)/env.sh
fi
source $(dirname $0)/env.sh

# Include utilities
source "${UBIRD_UTILS}"

# Set verbosity
set_verbosity

readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly NC="\033[0m"

declare -a PATCH_CMD
readonly PATCH_CMD=("${UBIRD_PATCH}" -p1 --no-backup-if-mismatch)

declare -a PATCH_FILES
declare -a ATN_PATCH_FILES

# shellcheck disable=SC2207
readonly PATCH_FILES=($("${UBIRD_YQ}" '.patches[].file' "$("${UBIRD_DIRNAME}" "$0")"/patches.yaml))
# shellcheck disable=SC2207
readonly ATN_PATCH_FILES=($("${UBIRD_YQ}" '.patches[].file' "$("${UBIRD_DIRNAME}" "$0")"/patches-atn.yaml))

function check_patch() {
  local -r patch="${UBIRD_PATCHES}/$1"
  if [[ ! -f "${patch}" ]]; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "$patch")"
    echo "'$patch' does not exist or is not a file"
    return 1
  fi

  if ! "${PATCH_CMD[@]}" --dry-run < "${patch}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Incompatible patch: '${patch}'"
    return 1
  fi
}

function check_patches() {
  for patch in "${PATCH_FILES[@]}"; do
    if ! check_patch "${patch}"; then
      return 1
    fi
  done
}

function check_patches_atn() {
  for patch in "${ATN_PATCH_FILES[@]}"; do
    if ! check_patch "${patch}"; then
      return 1
    fi
  done
}

function test_patches() {
  for patch in "${PATCH_FILES[@]}"; do
    if ! check_patch "${patch}" > /dev/null 2>&1; then
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    else
      printf "${GREEN}✓ %-45s: OK${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    fi
  done
}

function test_patches_atn() {
  for patch in "${ATN_PATCH_FILES[@]}"; do
    if ! check_patch "${patch}" > /dev/null 2>&1; then
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    else
      printf "${GREEN}✓ %-45s: OK${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    fi
  done
}

function apply_patch() {
  local -r name="$1"
  echo "Applying patch: ${name}"
  check_patch "${name}" || return 1
  "${PATCH_CMD[@]}" < "${UBIRD_PATCHES}/${name}"
  return $?
}

function apply_patches() {
  for patch in "${PATCH_FILES[@]}"; do
    if ! apply_patch "${patch}"; then
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
      echo "Failed to apply ${patch}"
      return 1
    fi
  done
}

function apply_patches_atn() {
  for patch in "${ATN_PATCH_FILES[@]}"; do
    if ! apply_patch "${patch}"; then
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
      echo "Failed to apply ${patch}"
      return 1
    fi
  done
}

function list_patches() {
  for patch in "${PATCH_FILES[@]}"; do
    echo "${patch}"
  done
}

function list_patches_atn() {
  for patch in "${ATN_PATCH_FILES[@]}"; do
    echo "${patch}"
  done
}

function slugify() {
  local -r input="$1"
  echo "${input}" |
    "${UBIRD_TR}" '[:upper:]' '[:lower:]' |
    "${UBIRD_SED}" -E 's/[^a-z0-9]+/-/g' |
    "${UBIRD_SED}" -E 's/^-+|-+$//g'
}

# Function to rebase a single patch file atomically
# Usage: rebase_patch <compatible_tag> <target_tag> <patch_file_path>
function rebase_patch() {
  local -r compatible_tag="$1"
  local -r target_tag="$2"
  local -r patch_file="$3"

  # Validate inputs
  if [[ -z "${compatible_tag}" || -z "${target_tag}" || -z "${patch_file}" ]]; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Missing required parameters" >&2
    echo "Usage: rebase_patch <compatible_tag> <target_tag> <patch_file_path>" >&2
    return 1
  fi

  if [[ ! -f "${patch_file}" ]]; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Patch file '${patch_file}' does not exist" >&2
    return 1
  fi

  # Store original state for rollback
  local -r original_branch=$("${UBIRD_GIT}" rev-parse --abbrev-ref HEAD 2> /dev/null)

  local -r original_stash_count=$("${UBIRD_GIT}" stash list | "${UBIRD_WC}" -l)

  local -r patch_name=$("${UBIRD_BASENAME}" "${patch_file}" .patch)

  local -r branch_name="rebase-${patch_name}"

  function cleanup_and_rollback() {
    echo "Error occurred, rolling back changes..." >&2

    # Check if we're in the middle of a rebase and abort it
    if "${UBIRD_GIT}" status --porcelain=v1 2> /dev/null | "${UBIRD_GREP}" -q "^R" ||
      [[ -d "$("${UBIRD_GIT}" rev-parse --git-dir)/rebase-merge" ]] ||
      [[ -d "$("${UBIRD_GIT}" rev-parse --git-dir)/rebase-apply" ]]; then
      echo "Aborting rebase in progress..."
      "${UBIRD_GIT}" rebase --abort 2> /dev/null
    fi

    # Switch back to original branch if it exists
    if [[ -n "${original_branch}" && "${original_branch}" != "HEAD" ]]; then
      "${UBIRD_GIT}" checkout "${original_branch}" 2> /dev/null
    fi

    # Delete the temporary branch if it was created
    "${UBIRD_GIT}" branch -D "${branch_name}" 2> /dev/null

    # Restore stashed changes if any were created
    local -r current_stash_count=$("${UBIRD_GIT}" stash list | "${UBIRD_WC}" -l)
    if [[ "${current_stash_count}" -gt "${original_stash_count}" ]]; then
      "${UBIRD_GIT}" stash pop 2> /dev/null
    fi

    return 1
  }

  # Ensure clean git directory state
  if ! "${UBIRD_GIT}" diff-index --quiet HEAD --; then
    echo "Stashing uncommitted changes..."
    if ! "${UBIRD_GIT}" stash push -m "Temporary stash for patch rebase"; then
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
      echo "Failed to stash changes" >&2
      return 1
    fi
  fi

  # Check if tags exist
  if ! "${UBIRD_GIT}" rev-parse --verify "${compatible_tag}" > /dev/null 2>&1; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Compatible tag '${compatible_tag}' does not exist" >&2
    cleanup_and_rollback
    return 1
  fi

  if ! "${UBIRD_GIT}" rev-parse --verify "${target_tag}" > /dev/null 2>&1; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Target tag '${target_tag}' does not exist" >&2
    cleanup_and_rollback
    return 1
  fi

  # Checkout the compatible tag
  echo "Checking out compatible tag '${compatible_tag}'..."
  if ! "${UBIRD_GIT}" checkout "${compatible_tag}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to checkout compatible tag '${compatible_tag}'" >&2
    cleanup_and_rollback
    return 1
  fi

  # Create and switch to new branch
  echo "Creating branch '${branch_name}'..."
  if ! "${UBIRD_GIT}" checkout -b "${branch_name}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to create branch '${branch_name}'" >&2
    cleanup_and_rollback
    return 1
  fi

  # Apply the patch
  echo "Applying patch '${patch_file}'..."
  if ! "${UBIRD_GIT}" apply "${patch_file}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to apply '${patch_file}'" >&2
    cleanup_and_rollback
    return 1
  fi

  # Stage all changes
  if ! "${UBIRD_GIT}" add .; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to stage changes" >&2
    cleanup_and_rollback
    return 1
  fi

  # Commit the changes
  local -r commit_message="Apply patch $("${UBIRD_BASENAME}" "${patch_file}") - rebased to ${target_tag}"
  echo "Committing changes..."
  if ! "${UBIRD_GIT}" commit -m "${commit_message}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to commit changes" >&2
    cleanup_and_rollback
    return 1
  fi

  # Rebase to target tag
  echo "Rebasing to target tag '${target_tag}'..."
  if ! "${UBIRD_GIT}" rebase "${target_tag}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to rebase to target tag '${target_tag}'" >&2
    cleanup_and_rollback
    return 1
  fi

  # Update the patch file using git format-patch
  echo "Updating patch file..."
  local -r temp_patch=$("${UBIRD_MKTEMP}")
  if ! "${UBIRD_GIT}" format-patch -1 --stdout > "${temp_patch}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to generate new patch" >&2
    "${UBIRD_RM}" -f "${temp_patch}"
    cleanup_and_rollback
    return 1
  fi

  # Atomically replace the original patch file
  if ! "${UBIRD_MV}" "${temp_patch}" "${patch_file}"; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Failed to update patch file" >&2
    "${UBIRD_RM}" -f "${temp_patch}"
    cleanup_and_rollback
    return 1
  fi

  # Cleanup: switch back to original branch and delete temporary branch
  if [[ -n "${original_branch}" && "${original_branch}" != "HEAD" ]]; then
    "${UBIRD_GIT}" checkout "${original_branch}"
  else
    "${UBIRD_GIT}" checkout "${target_tag}"
  fi

  "${UBIRD_GIT}" branch -D "${branch_name}"

  # Restore stashed changes if any
  local -r current_stash_count=$("${UBIRD_GIT}" stash list | "${UBIRD_WC}" -l)
  if [[ "${current_stash_count}" -gt "${original_stash_count}" ]]; then
    echo "Restoring stashed changes..."
    "${UBIRD_GIT}" stash pop
  fi

  printf "${GREEN}✓ %-45s: SUCCESS${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
  echo "Rebased patch '${patch_file}' from '${compatible_tag}' to '${target_tag}'"
  return 0
}

# Function to rebase multiple patch files
# Usage: rebase_patches <compatible_tag> <target_tag> <patch_file1> [patch_file2] [...]
function rebase_patches() {
  local -r compatible_tag="$1"
  local -r target_tag="$2"

  # Validate inputs
  if [[ -z "${compatible_tag}" || -z "${target_tag}" ]]; then
    printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
    echo "Missing required parameters" >&2
    echo "Usage: rebase_patches <compatible_tag> <target_tag>" >&2
    return 1
  fi

  local success_count=0
  local failure_count=0
  local failed_patches=()

  echo "Starting batch rebase of ${#PATCH_FILES[@]} patch files..."
  echo "Compatible tag: ${compatible_tag}"
  echo "Target tag: ${target_tag}"
  echo "----------------------------------------"

  for patch_file in "${PATCH_FILES[@]}"; do
    echo "Processing: ${patch_file}"

    if rebase_patch "${compatible_tag}" "${target_tag}" "${patch_file}"; then
      printf "${GREEN}✓ %-45s: SUCCESS${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
      ((success_count++))
    else
      printf "${RED}✗ %-45s: FAILED${NC}\n" "$("${UBIRD_BASENAME}" "${patch}")"
      failed_patches+=("${patch_file}")
      ((failure_count++))
    fi
    echo "----------------------------------------"
  done

  # Summary
  echo "Batch rebase completed:"
  echo "  Successful: ${success_count}"
  echo "  Failed: ${failure_count}"

  if [[ "${failure_count}" -gt 0 ]]; then
    echo "Failed patches:"
    for failed_patch in "${failed_patches[@]}"; do
      echo "  - ${failed_patch}"
    done
    return 1
  fi

  return 0
}
