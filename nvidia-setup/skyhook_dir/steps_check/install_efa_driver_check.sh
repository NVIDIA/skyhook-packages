#!/bin/bash
set -e
# EFA installer typically installs to /opt/amazon/efa; check for presence
if [ -d /opt/amazon/efa ]; then
  exit 0
fi
# Fallback: check for libfabric or known EFA lib
if ldconfig -p 2>/dev/null | grep -q libfabric; then
  exit 0
fi
echo "EFA driver not found (expected /opt/amazon/efa or libfabric)" >&2
exit 1
