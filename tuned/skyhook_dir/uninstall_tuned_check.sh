#!/bin/bash
set -x

# wait for tuned
sleep 1

# ensure that tuned is uninstalled
if command -v tuned >/dev/null 2>&1; then
    echo "ERROR: tuned is still installed."
    exit 1
fi

# ensure that tuned-adm is uninstalled
if command -v tuned-adm >/dev/null 2>&1; then
    echo "ERROR: tuned-adm is still installed."
    exit 1
fi

# ensure that the tuned service is stopped
if systemctl is-active --quiet tuned; then
    echo "ERROR: tuned is still running"
    exit 1
fi

# ensure that the tuned service is disabled
if systemctl is-enabled --quiet tuned; then
    echo "ERROR: tuned is still enabled at boot"
    exit 1
fi