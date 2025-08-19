#!/bin/bash
set -x

CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
TUNED_DIR="/etc/tuned"

# check tuned service is installed and running
if ! command -v tuned-adm >/dev/null 2>&1; then
    echo "ERROR: tuned-adm is not installed"
    exit 1
fi

if ! systemctl is-active --quiet tuned; then
    echo "ERROR: tuned service is not running"
    exit 1
fi

# check configmaps directory exists
if [ ! -d "$CONFIGMAP_DIR" ]; then
    echo "ERROR: configmaps directory does not exist: $CONFIGMAP_DIR"
    exit 1
fi

# verify custom profiles
for file in "$CONFIGMAP_DIR"/*; do
    [ -f "$file" ] || continue

    base_file=$(basename "$file")
    [ "$base_file" = "tuned_profile" ] && continue

    custom_profile_dir="$TUNED_DIR/$base_file"
    custom_profile_file="$custom_profile_dir/tuned.conf"

    if [ ! -d "$custom_profile_dir" ]; then
        echo "ERROR: custom tuned profile directory missing: $custom_profile_dir"
        exit 1
    fi

    if [ ! -f "$custom_profile_file" ]; then
        echo "ERROR: tuned configuration file missing: $custom_profile_file"
        exit 1
    fi

    echo "verified custom profile: $base_file"
done

# verify the main profile is active
TUNED_PROFILE_FILE="$CONFIGMAP_DIR/tuned_profile"
if [ ! -f "$TUNED_PROFILE_FILE" ]; then
    echo "WARNING: tuned_profile file missing in $CONFIGMAP_DIR"
else
    tuned_profile=$(cat "$TUNED_PROFILE_FILE" | xargs)
    if tuned-adm list | grep -q "^- $tuned_profile"; then
        active_profile=$(tuned-adm active | awk -F: '{print $2}' | xargs)
        if [ "$active_profile" != "$tuned_profile" ]; then
            echo "ERROR: tuned profile '$tuned_profile' is not active (active: $active_profile)"
            exit 1
        fi
    else
        echo "ERROR: tuned profile '$tuned_profile' not found in tuned-adm list"
        exit 1
    fi
fi

# verify that the profile is applied
if ! tuned-adm verify; then
    echo "ERROR: tuned-adm verify failed"

    echo "tuned-adm verify logs:"
    cat /var/log/tuned/tuned.log

    if [[ "${INTERRUPT}" != "true" ]]; then
        echo "WARNING: Set the INTERRUPT environment variable to true if you're tunings require an interrupt or else the tunings can't be verified"
        exit 1
    fi
fi 