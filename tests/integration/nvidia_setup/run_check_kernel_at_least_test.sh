#!/bin/bash
# Test harness for check_kernel_at_least and check_kernel_exact. Set CURRENT_KERNEL,
# REQUIRED_KERNEL, and optionally KERNEL_CHECK_MODE=at_least|exact (default: at_least).
# Source ensure_kernel.sh (with uname mocked) and run the chosen check.
# Exit code 0 = pass, 1 = fail.
set -e

CURRENT_KERNEL="${CURRENT_KERNEL:?CURRENT_KERNEL must be set}"
REQUIRED_KERNEL="${REQUIRED_KERNEL:?REQUIRED_KERNEL must be set}"
KERNEL_CHECK_MODE="${KERNEL_CHECK_MODE:-at_least}"
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

case "${KERNEL_CHECK_MODE}" in
  at_least) check_kernel_at_least "$REQUIRED_KERNEL" ;;
  exact)    check_kernel_exact "$REQUIRED_KERNEL" ;;
  *)        echo "KERNEL_CHECK_MODE must be at_least or exact" >&2; exit 1 ;;
esac
exit $?
