#!/bin/bash
set -e
if [ ! -x /usr/local/bin/setup-local-disks ]; then
  echo "/usr/local/bin/setup-local-disks missing or not executable" >&2
  exit 1
fi
exit 0
