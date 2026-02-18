#!/bin/bash
set -e
CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
DEFAULTS_DIR="${SKYHOOK_DIR}/skyhook_dir/defaults"
STEPS_DIR="${SKYHOOK_DIR}/skyhook_dir/steps"

SERVICE=$(cat "${CONFIGMAP_DIR}/service")
ACCELERATOR=$(cat "${CONFIGMAP_DIR}/accelerator")
COMBINATION="${SERVICE}-${ACCELERATOR}"
DEFAULTS_FILE="${DEFAULTS_DIR}/${COMBINATION}.conf"

if [ ! -f "${DEFAULTS_FILE}" ]; then
  echo "Unsupported combination: service=${SERVICE} accelerator=${ACCELERATOR}" >&2
  echo "Supported: $(find "${DEFAULTS_DIR}" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Load defaults (KERNEL=, LUSTRE=, EFA=)
# shellcheck source=/dev/null
. "${DEFAULTS_FILE}"

# Env overrides
[ -n "${NVIDIA_KERNEL:-}" ] && KERNEL="${NVIDIA_KERNEL}"
[ -n "${NVIDIA_LUSTRE:-}" ] && LUSTRE="${NVIDIA_LUSTRE}"
[ -n "${NVIDIA_EFA:-}" ] && EFA="${NVIDIA_EFA}"

export KERNEL LUSTRE EFA
# SKYHOOK_DIR is set by the agent; ensure step scripts see it
export SKYHOOK_DIR

run_eks_h100() {
  "${STEPS_DIR}/upgrade.sh"
  "${STEPS_DIR}/install-efa-driver.sh" "${EFA}"
  "${STEPS_DIR}/install-lustre.sh" "${KERNEL}" "${LUSTRE}"
  "${STEPS_DIR}/configure-chrony.sh"
  "${STEPS_DIR}/setup_local_disks.sh" raid0
}

run_eks_gb200() {
  "${STEPS_DIR}/upgrade.sh"
  "${STEPS_DIR}/install-efa-driver.sh" "${EFA}"
  "${STEPS_DIR}/install-lustre.sh" "${KERNEL}" "${LUSTRE}"
  "${STEPS_DIR}/configure-chrony.sh"
  "${STEPS_DIR}/setup_local_disks.sh" raid0
}

case "${COMBINATION}" in
  eks-h100)  run_eks_h100 ;;
  eks-gb200) run_eks_gb200 ;;
  *)
    echo "Unsupported combination: ${COMBINATION}" >&2
    echo "Supported: $(find "${DEFAULTS_DIR}" -maxdepth 1 -name '*.conf' -exec basename {} .conf \; 2>/dev/null | tr '\n' ' ')" >&2
    exit 1
    ;;
esac
