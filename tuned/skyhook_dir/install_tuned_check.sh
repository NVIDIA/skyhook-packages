#!/bin/bash
set -x

# wait for tuned
sleep 1

# ensure that tuned is installed
if ! command -v tuned >/dev/null 2>&1; then
    echo "ERROR: tuned is not installed."
    exit 1
fi

# ensure that tuned-adm is installed
if ! command -v tuned-adm >/dev/null 2>&1; then
    echo "ERROR: tuned-adm is not installed."
    exit 1
fi

# ensure that the tuned service is started
if ! systemctl is-active --quiet tuned; then
    echo "ERROR: tuned isn't running"
    exit 1
fi

# ensure that the tuned service is enabled so it
# starts on system bring up
if ! systemctl is-enabled --quiet tuned; then
    echo "ERROR: tuned is not enabled at boot"
    exit 1
fi
