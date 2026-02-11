#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prepares NVIDIA tuned profiles by:
# 1. Copying common base profiles to /usr/lib/tuned/
# 2. Selecting the appropriate OS-specific workload profile
# 3. Setting up the cloud provider profile with dynamic include

set -xe
set -u

CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
PROFILES_DIR="${SKYHOOK_DIR}/profiles"
TUNED_SYSTEM_DIR="/usr/lib/tuned"
TUNED_USER_DIR="/etc/tuned"

# Read profile and provider from configmap
PROFILE_FILE="$CONFIGMAP_DIR/profile"
PROVIDER_FILE="$CONFIGMAP_DIR/provider"

# Detect OS from /etc/os-release
detect_os() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        # Get major.minor version (e.g., "24.04" from "24.04.1")
        VERSION="${VERSION_ID:-unknown}"
        # For RHEL-like systems, just use the major version
        case "$OS_ID" in
            rhel|centos|rocky|almalinux|amzn)
                VERSION=$(echo "$VERSION" | cut -d. -f1)
                ;;
        esac
        echo "Detected OS: $OS_ID $VERSION"
    else
        echo "ERROR: /etc/os-release not found"
        exit 1
    fi
}

# Copy common base profiles to /usr/lib/tuned/
deploy_common_profiles() {
    echo "Deploying common profiles to $TUNED_SYSTEM_DIR..."
    
    if [ -d "$PROFILES_DIR/common" ]; then
        for profile_dir in "$PROFILES_DIR/common"/*/; do
            [ -d "$profile_dir" ] || continue
            profile_name=$(basename "$profile_dir")
            sudo cp -rL "$profile_dir" "$TUNED_SYSTEM_DIR/$profile_name"
            echo "Deployed common profile: $profile_name"
        done
    else
        echo "WARNING: No common profiles directory found at $PROFILES_DIR/common"
    fi
}

# Deploy ALL OS-specific workload profiles
deploy_os_profiles() {
    echo "Deploying OS profiles to $TUNED_USER_DIR..."
    
    local os_dir=""
    
    # Try OS-specific path first, then fall back to os/common
    if [ -d "$PROFILES_DIR/os/$OS_ID/$VERSION" ]; then
        os_dir="$PROFILES_DIR/os/$OS_ID/$VERSION"
        echo "Using OS-specific profiles from: $OS_ID/$VERSION"
    elif [ -d "$PROFILES_DIR/os/common" ]; then
        os_dir="$PROFILES_DIR/os/common"
        echo "Using common OS profiles from: os/common"
    else
        echo "ERROR: No OS profiles found in os/$OS_ID/$VERSION/ or os/common/"
        exit 1
    fi
    
    # Copy ALL profiles from the OS directory (dereference symlinks with -L)
    sudo mkdir -p "$TUNED_USER_DIR"
    for profile_dir in "$os_dir"/*/; do
        [ -d "$profile_dir" ] || continue
        profile_name=$(basename "$profile_dir")
        sudo cp -rL "$profile_dir" "$TUNED_USER_DIR/$profile_name"
        echo "Deployed OS profile: $profile_name"
    done
}

# Validate that the requested profile exists
validate_profile() {
    local profile=$1
    
    if [ ! -d "$TUNED_USER_DIR/$profile" ]; then
        echo "ERROR: Requested profile '$profile' not found in $TUNED_USER_DIR"
        echo "Available profiles:"
        ls -1 "$TUNED_USER_DIR" 2>/dev/null || echo "  (none)"
        exit 1
    fi
    
    echo "Validated profile exists: $profile"
}

# Deploy cloud provider profile with dynamic include
deploy_provider_profile() {
    local provider=$1
    local profile=$2
    local provider_dir="$PROFILES_DIR/cloud/$provider"
    
    if [ ! -d "$provider_dir" ]; then
        echo "ERROR: Provider '$provider' not found at $provider_dir"
        exit 1
    fi
    
    # Create provider profile directory
    sudo mkdir -p "$TUNED_USER_DIR/$provider"
    
    # Copy template and inject include line
    local template="$provider_dir/tuned.conf.template"
    if [ -f "$template" ]; then
        # Insert include= line after [main]
        sed "s/^\[main\]/[main]\ninclude=$profile/" "$template" | sudo tee "$TUNED_USER_DIR/$provider/tuned.conf" > /dev/null
        echo "Created provider profile: $provider with include=$profile"
    else
        echo "ERROR: Provider template not found: $template"
        exit 1
    fi
    
    # Copy any additional files (scripts, etc.)
    for file in "$provider_dir"/*; do
        [ -f "$file" ] || continue
        filename=$(basename "$file")
        [ "$filename" = "tuned.conf.template" ] && continue
        sudo cp "$file" "$TUNED_USER_DIR/$provider/$filename"
        sudo chmod +x "$TUNED_USER_DIR/$provider/$filename" 2>/dev/null || true
        echo "Copied provider file: $filename"
    done
}

# Write the active profile name for apply_tuned_profile.sh
write_tuned_profile() {
    local active_profile=$1
    echo "$active_profile" | sudo tee "$CONFIGMAP_DIR/tuned_profile" > /dev/null
    echo "Set active tuned profile: $active_profile"
}

main() {
    # Detect OS
    detect_os
    
    # Deploy common base profiles to /usr/lib/tuned/
    deploy_common_profiles
    
    # Deploy ALL OS-specific profiles to /etc/tuned/
    deploy_os_profiles
    
    # Read profile from configmap (required)
    if [ ! -f "$PROFILE_FILE" ]; then
        echo "ERROR: Profile configmap not found at $PROFILE_FILE"
        exit 1
    fi
    PROFILE=$(cat "$PROFILE_FILE" | xargs)
    echo "Requested profile: $PROFILE"
    
    # Validate the requested profile exists
    validate_profile "$PROFILE"
    
    # Check if provider is specified (optional)
    if [ -f "$PROVIDER_FILE" ]; then
        PROVIDER=$(cat "$PROVIDER_FILE" | xargs)
        if [ -n "$PROVIDER" ]; then
            echo "Requested provider: $PROVIDER"
            deploy_provider_profile "$PROVIDER" "$PROFILE"
            # Active profile is the provider (which includes the workload profile)
            write_tuned_profile "$PROVIDER"
        else
            # No provider, use workload profile directly
            write_tuned_profile "$PROFILE"
        fi
    else
        # No provider file, use workload profile directly
        write_tuned_profile "$PROFILE"
    fi
    
    echo "Profile preparation complete"
}

main "$@"
