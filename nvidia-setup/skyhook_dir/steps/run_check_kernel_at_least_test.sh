#!/bin/bash
# Test harness for check_kernel_at_least. Set CURRENT_KERNEL and REQUIRED_KERNEL,
# then source ensure_kernel.sh (with uname mocked) and run the check. Exit code
# 0 = current >= required, 1 = current < required.
set -e

CURRENT_KERNEL="${CURRENT_KERNEL:?CURRENT_KERNEL must be set}"
REQUIRED_KERNEL="${REQUIRED_KERNEL:?REQUIRED_KERNEL must be set}"
[ -n "${SKYHOOK_DIR:-}" ] || { echo "SKYHOOK_DIR must be set" >&2; exit 1; }

uname() {
  if [ "$1" = "-r" ]; then
    echo "$CURRENT_KERNEL"
  else
    /usr/bin/uname "$@"
  fi
}
export TEST_CHECK_KERNEL_AT_LEAST=1
# shellcheck source=ensure_kernel.sh
. "${SKYHOOK_DIR}/skyhook_dir/steps/ensure_kernel.sh"

check_kernel_at_least "$REQUIRED_KERNEL"
exit $?
