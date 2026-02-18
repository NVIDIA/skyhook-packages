#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
if [ -z "${SKIP_SYSTEM_OPERATIONS:-}" ]; then
  apt-get upgrade -y
else
  echo "Skipping system upgrade for test environment"
fi
apt-get install -y curl git wget gpg
