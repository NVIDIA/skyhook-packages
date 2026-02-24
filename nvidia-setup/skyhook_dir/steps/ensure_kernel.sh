#!/bin/bash
# ensure_kernel.sh: install exact kernel (if NVIDIA_SETUP_INSTALL_KERNEL=true) or
# verify current kernel is >= required (if false).
set -e

STEPS_DIR="${SKYHOOK_DIR}/skyhook_dir/steps"

if [ -f "${SKYHOOK_DIR}/skyhook_dir/utilities.sh" ]; then
  # shellcheck source=../utilities.sh
  . "${SKYHOOK_DIR}/skyhook_dir/utilities.sh"
elif [ -f "$(dirname "$0")/../utilities.sh" ]; then
  . "$(dirname "$0")/../utilities.sh"
else
  echo "ERROR: utilities.sh not found" >&2
  exit 1
fi

install_kernel() {
  "${STEPS_DIR}/downgrade_kernel.sh" "${KERNEL}"
}

# Returns 0 if current >= required (by version sort)
check_kernel_at_least() {
  local required="$1"
  local current
  current=$(uname -r)
  local first
  first=$(printf '%s\n' "${required}" "${current}" | sort -V | head -n1)
  if [ "${first}" = "${required}" ]; then
    return 0
  fi
  return 1
}

if [ "${NVIDIA_SETUP_INSTALL_KERNEL:-false}" = "true" ]; then
  install_kernel
  exit 0
fi

# Check current kernel is >= required
required_full="$(resolve_full_kernel "${KERNEL}")"
if ! check_kernel_at_least "${required_full}"; then
  echo "Error: current kernel $(uname -r) is not >= required ${required_full}. Set NVIDIA_SETUP_INSTALL_KERNEL=true to install the exact kernel, or boot with a compatible kernel." >&2
  exit 1
fi
