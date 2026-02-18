#!/bin/bash
set -e
EFA_VERSION="${1:?EFA version required}"
export DEBIAN_FRONTEND=noninteractive
cd "$(mktemp -d)"
curl -sSfO "https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_VERSION}.tar.gz"
tar -xf "aws-efa-installer-${EFA_VERSION}.tar.gz"
cd aws-efa-installer
if [ -z "${SKIP_SYSTEM_OPERATIONS:-}" ]; then
  ./efa_installer.sh -y
else
  echo "Skipping efa install for test environment"
fi
