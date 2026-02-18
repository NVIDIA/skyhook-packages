#!/bin/bash
set -e
apt-get update -qq
# Optional: could check apt list --upgradable is empty; we only verify update succeeds
exit 0
