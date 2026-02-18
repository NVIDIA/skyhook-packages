#!/bin/bash
# resolve_full_kernel for nvidia-setup (skyhook): no get_var; use KERNEL and architecture.
# Usage: resolve_full_kernel <base_kernel_version>
# Returns: <base_kernel_version>-aws[-64k] for EKS
resolve_full_kernel() {
  local base_version="$1"
  if [ -z "${base_version}" ]; then
    base_version="${KERNEL:-}"
  fi
  if [ -z "${base_version}" ]; then
    echo "ERROR: kernel version not set" >&2
    return 1
  fi
  # EKS on AWS: suffix is -aws; optional -64k for arm64 if EIDOS_KERNEL_64K_ARM64=true
  local arch
  arch=$(uname -m)
  local suffix="-aws"
  if [ "${arch}" = "arm64" ] || [ "${arch}" = "aarch64" ]; then
    if [ "${EIDOS_KERNEL_64K_ARM64:-false}" = "true" ]; then
      suffix="-aws-64k"
    fi
  fi
  # If base_version already contains -aws or similar, avoid duplicating
  case "${base_version}" in
    *-aws*) echo "${base_version}" ;;
    *)      echo "${base_version}${suffix}" ;;
  esac
}
