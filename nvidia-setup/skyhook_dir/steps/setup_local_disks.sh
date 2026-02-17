#!/bin/bash
# Install setup-local-disks to /usr/local/bin and run it directly.
# Usage: run with optional first arg: raid0 | mount | none (default: raid0 for EKS)
set -e
DISK_MODE="${1:-raid0}"
cp "${SKYHOOK_DIR}/setup-local-disks.sh" /usr/local/bin/setup-local-disks
chmod 755 /usr/local/bin/setup-local-disks
/usr/local/bin/setup-local-disks "${DISK_MODE}"
