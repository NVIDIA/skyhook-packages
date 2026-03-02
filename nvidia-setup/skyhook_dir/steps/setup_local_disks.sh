#!/bin/bash
# Install setup-local-disks to /usr/local/bin and run it directly.
# Usage: run with optional first arg: raid0 | mount | none (default: raid0 for EKS)
set -e
DISK_MODE="${1:-raid0}"

# setup-local-disks uses mdadm (RAID) and mkfs.xfs; ensure they are installed
if ! command -v mdadm >/dev/null 2>&1 || ! command -v mkfs.xfs >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq mdadm xfsprogs
fi

cp "${SKYHOOK_DIR}/skyhook_dir/setup-local-disks.sh" /usr/local/bin/setup-local-disks
chmod 755 /usr/local/bin/setup-local-disks
/usr/local/bin/setup-local-disks "${DISK_MODE}"
