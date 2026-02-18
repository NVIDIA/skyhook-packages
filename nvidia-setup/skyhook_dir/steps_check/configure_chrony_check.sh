#!/bin/bash
set -e
if ! command -v chronyc >/dev/null 2>&1; then
  echo "chrony not installed" >&2
  exit 1
fi
if ! grep -q "169.254.169.123" /etc/chrony/chrony.conf 2>/dev/null; then
  echo "Chrony config missing IMDS server 169.254.169.123" >&2
  exit 1
fi
exit 0
