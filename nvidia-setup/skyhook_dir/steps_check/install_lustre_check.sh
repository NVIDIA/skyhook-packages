#!/bin/bash
set -e
KERNEL="${1:-$(uname -r)}"
# Lustre client modules package for this kernel
if dpkg -l 2>/dev/null | grep -q "lustre-client-modules-${KERNEL}"; then
  exit 0
fi
# Try without full kernel suffix (e.g. 5.15.0-1025-aws)
BASE="${KERNEL%-*}"
if dpkg -l 2>/dev/null | grep -q "lustre-client-modules"; then
  exit 0
fi
echo "Lustre client modules not found for kernel ${KERNEL}" >&2
exit 1
