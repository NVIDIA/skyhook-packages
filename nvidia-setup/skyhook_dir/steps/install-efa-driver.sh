#!/bin/bash
set -e
EFA_VERSION="${1:?EFA version required}"
export DEBIAN_FRONTEND=noninteractive


# Function to install EFA with retry logic
install_efa() {
  local install_dir
  
  install_dir="$(mktemp -d)"
  cd "${install_dir}"
  
  echo "Downloading EFA installer version ${EFA_VERSION}..."
  curl -sSfO "https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_VERSION}.tar.gz"
  tar -xf "aws-efa-installer-${EFA_VERSION}.tar.gz"
  cd aws-efa-installer

    
  # Check memory before each attempt
  if ! check_memory; then
    echo "Error: Insufficient memory for EFA installation" >&2
    exit 1
  fi
  
  ./efa_installer.sh -y
  echo "EFA installation completed successfully"
}

if [ -z "${SKIP_SYSTEM_OPERATIONS:-}" ]; then
  install_efa
else
  echo "Skipping efa install for test environment"
fi
