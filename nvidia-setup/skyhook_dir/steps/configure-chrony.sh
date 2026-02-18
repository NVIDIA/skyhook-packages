#!/bin/bash
set -euo pipefail
apt update
DEBIAN_FRONTEND=noninteractive apt install -y chrony
sed -i '/^pool/d' /etc/chrony/chrony.conf
echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" >> /etc/chrony/chrony.conf
echo "Configured Chrony"
