#!/bin/bash
set -xe
set -u

CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
TUNED_DIR="/etc/tuned"

# ensure tuned directory exists
sudo mkdir -p "$TUNED_DIR"

# process all other files as custom profiles
for file in "$CONFIGMAP_DIR"/*; do
    [ -f "$file" ] || continue # make sure file exists
    [ "$(basename "$file")" = "tuned_profile" ] && continue  # skip tuned_profile

    profile_name=$(basename "$file")
    custom_profile_dir="$TUNED_DIR/$profile_name"

    # Create a directory for the custom profile if it doesn't exist
    sudo mkdir -p "$custom_profile_dir"

    # Copy the file contents as tuned.conf
    sudo cp "$file" "$custom_profile_dir/tuned.conf"
    echo "created custom tuned profile: $profile_name"
done

# Now apply the main profile
TUNED_PROFILE_FILE="$CONFIGMAP_DIR/tuned_profile"
if [ -f "$TUNED_PROFILE_FILE" ]; then
    tuned_profile=$(cat "$TUNED_PROFILE_FILE" | xargs)  # read and trim
    if tuned-adm list | grep -q "^- $tuned_profile"; then
        echo "applying tuned profile: $tuned_profile"
        sudo tuned-adm profile "$tuned_profile"
    else
        echo "ERROR: tuned profile '$tuned_profile' not found"
        exit 1
    fi
else
    echo "WARNING: no tuned_profile file found in $CONFIGMAP_DIR"
fi
