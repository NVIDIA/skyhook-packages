#!/bin/bash
# Verify running kernel matches expected from defaults/env overrides.
# Only runs when NVIDIA_SETUP_INSTALL_KERNEL=true (same env var that triggers kernel install).
set -e

if [ "${NVIDIA_SETUP_INSTALL_KERNEL:-false}" != "true" ]; then
  exit 0
fi

# shellcheck source=../load_defaults.sh
. "${SKYHOOK_DIR}/skyhook_dir/load_defaults.sh"

if [ -f "${SKYHOOK_DIR}/skyhook_dir/utilities.sh" ]; then
  # shellcheck source=../utilities.sh
  . "${SKYHOOK_DIR}/skyhook_dir/utilities.sh"
elif [ -f "$(dirname "$0")/../utilities.sh" ]; then
  . "$(dirname "$0")/../utilities.sh"
else
  echo "ERROR: utilities.sh not found" >&2
  exit 1
fi

expected="$(resolve_full_kernel "${KERNEL}")"
current=$(uname -r)

if [ "${current}" != "${expected}" ]; then
  echo "Error: running kernel ${current} does not match expected ${expected} (from defaults/env)." >&2
  exit 1
fi

exit 0
