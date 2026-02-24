#!/bin/bash
set -e
STEPS_CHECK_DIR="${SKYHOOK_DIR}/skyhook_dir/steps_check"

# When NVIDIA_SETUP_INSTALL_KERNEL=true, only verify kernel (same env that triggered kernel install)
if [ "${NVIDIA_SETUP_INSTALL_KERNEL:-false}" = "true" ]; then
  "${STEPS_CHECK_DIR}/kernel_install_check.sh"
  exit
fi

# shellcheck source=load_defaults.sh
. "${SKYHOOK_DIR}/skyhook_dir/load_defaults.sh"

check_eks_h100() {
  "${STEPS_CHECK_DIR}/upgrade_check.sh"
  "${STEPS_CHECK_DIR}/install_efa_driver_check.sh"
  # "${STEPS_CHECK_DIR}/install_lustre_check.sh" "${KERNEL}"
  # "${STEPS_CHECK_DIR}/configure_chrony_check.sh"
  # "${STEPS_CHECK_DIR}/setup_local_disks_check.sh"
}

check_eks_gb200() {
  "${STEPS_CHECK_DIR}/upgrade_check.sh"
  "${STEPS_CHECK_DIR}/install_efa_driver_check.sh"
  # "${STEPS_CHECK_DIR}/install_lustre_check.sh" "${KERNEL}"
  # "${STEPS_CHECK_DIR}/configure_chrony_check.sh"
  # "${STEPS_CHECK_DIR}/setup_local_disks_check.sh"
}

case "${COMBINATION}" in
  eks-h100)  check_eks_h100 ;;
  eks-gb200) check_eks_gb200 ;;
  *)
    echo "Unsupported combination: ${COMBINATION}" >&2
    echo "Supported: $(find "${DEFAULTS_DIR}" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; 2>/dev/null | tr '\n' ' ')" >&2
    exit 1
    ;;
esac
