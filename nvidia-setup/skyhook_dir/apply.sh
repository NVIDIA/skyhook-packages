#!/bin/bash
set -e
STEPS_DIR="${SKYHOOK_DIR}/skyhook_dir/steps"

# shellcheck source=load_defaults.sh
. "${SKYHOOK_DIR}/skyhook_dir/load_defaults.sh"

NVIDIA_SETUP_INSTALL_KERNEL="${NVIDIA_SETUP_INSTALL_KERNEL:-false}"
export NVIDIA_SETUP_INSTALL_KERNEL SKYHOOK_DIR

# If only installing kernel: run ensure_kernel (which installs and may reboot) and exit
if [ "${NVIDIA_SETUP_INSTALL_KERNEL}" = "true" ]; then
  "${STEPS_DIR}/ensure_kernel.sh"
  exit 0
fi

# Otherwise: ensure current kernel is >= required, then run full apply
"${STEPS_DIR}/ensure_kernel.sh"

run_aws_h100() {
  "${STEPS_DIR}/upgrade.sh"
  "${STEPS_DIR}/install-efa-driver.sh" "${EFA}"
  "${STEPS_DIR}/install_ofi.sh"
  # "${STEPS_DIR}/install-lustre.sh" "${KERNEL}" "${LUSTRE}"
  "${STEPS_DIR}/configure-chrony.sh"
  "${STEPS_DIR}/setup_local_disks.sh" raid0
}

run_aws_gb200() {
  "${STEPS_DIR}/upgrade.sh"
  "${STEPS_DIR}/install-efa-driver.sh" "${EFA}"
  "${STEPS_DIR}/install_ofi.sh"
  # "${STEPS_DIR}/install-lustre.sh" "${KERNEL}" "${LUSTRE}"
  "${STEPS_DIR}/configure-chrony.sh"
  "${STEPS_DIR}/setup_local_disks.sh" raid0
}

case "${COMBINATION}" in
  aws-h100)  run_aws_h100 ;;
  aws-gb200) run_aws_gb200 ;;
  *)
    echo "Unsupported combination: ${COMBINATION}" >&2
    echo "Supported: $(find "${DEFAULTS_DIR}" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; 2>/dev/null | tr '\n' ' ')" >&2
    exit 1
    ;;
esac
