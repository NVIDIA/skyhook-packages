#!/bin/bash
set -e
CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
DEFAULTS_DIR="${SKYHOOK_DIR}/skyhook_dir/defaults"
STEPS_CHECK_DIR="${SKYHOOK_DIR}/skyhook_dir/steps_check"

SERVICE=$(cat "${CONFIGMAP_DIR}/service")
ACCELERATOR=$(cat "${CONFIGMAP_DIR}/accelerator")
COMBINATION="${SERVICE}-${ACCELERATOR}"
DEFAULTS_FILE="${DEFAULTS_DIR}/${COMBINATION}.conf"

if [ ! -f "${DEFAULTS_FILE}" ]; then
  echo "Unsupported combination: service=${SERVICE} accelerator=${ACCELERATOR}" >&2
  echo "Supported: $(find "${DEFAULTS_DIR}" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "${DEFAULTS_FILE}"
[ -n "${EIDOS_KERNEL:-}" ] && KERNEL="${EIDOS_KERNEL}"
[ -n "${EIDOS_LUSTRE:-}" ] && LUSTRE="${EIDOS_LUSTRE}"
[ -n "${EIDOS_EFA:-}" ] && EFA="${EIDOS_EFA}"
export KERNEL

check_eks_h100() {
  "${STEPS_CHECK_DIR}/upgrade_check.sh"
  "${STEPS_CHECK_DIR}/install_efa_driver_check.sh"
  "${STEPS_CHECK_DIR}/install_lustre_check.sh" "${KERNEL}"
  "${STEPS_CHECK_DIR}/configure_chrony_check.sh"
  "${STEPS_CHECK_DIR}/setup_local_disks_check.sh"
}

check_eks_gb200() {
  "${STEPS_CHECK_DIR}/upgrade_check.sh"
  "${STEPS_CHECK_DIR}/install_efa_driver_check.sh"
  "${STEPS_CHECK_DIR}/install_lustre_check.sh" "${KERNEL}"
  "${STEPS_CHECK_DIR}/configure_chrony_check.sh"
  "${STEPS_CHECK_DIR}/setup_local_disks_check.sh"
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
