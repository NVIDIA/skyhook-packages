#!/bin/bash
# Post-interrupt check: after reboot from kernel-only install, verify running kernel
# matches the expected version (set when NVIDIA_SETUP_INSTALL_KERNEL=true).
set -e

STEPS_CHECK_DIR="${SKYHOOK_DIR}/skyhook_dir/steps_check"

"${STEPS_CHECK_DIR}/kernel_install_check.sh"
