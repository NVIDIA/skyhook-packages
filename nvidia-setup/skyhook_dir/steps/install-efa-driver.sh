#!/bin/bash
set -e
EFA_VERSION="${1:?EFA version required}"
export DEBIAN_FRONTEND=noninteractive

# Skip if EFA is already installed (same criteria as install_efa_driver_check.sh)
efa_already_installed() {
  [ -d /opt/amazon/efa ] && return 0
  ldconfig -p 2>/dev/null | grep -q libfabric && return 0
  dkms status 2>/dev/null | grep -q 'efa.*installed' && return 0
  return 1
}
if efa_already_installed; then
  echo "EFA already installed, skipping."
  exit 0
fi

# Function to install EFA with retry logic
install_efa() {
  echo "Downloading EFA installer version ${EFA_VERSION}..."
  curl -sSfO "https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_VERSION}.tar.gz"
  tar -xf "aws-efa-installer-${EFA_VERSION}.tar.gz"
  cd aws-efa-installer
  
  ./efa_installer.sh -y
  echo "EFA installation completed successfully"
}

if [ -z "${SKIP_SYSTEM_OPERATIONS:-}" ]; then
  install_efa
else
  echo "Skipping efa install for test environment"
fi
