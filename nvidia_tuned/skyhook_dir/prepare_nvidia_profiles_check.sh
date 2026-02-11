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

# Verifies that NVIDIA tuned profiles have been properly prepared

set -x

CONFIGMAP_DIR="${SKYHOOK_DIR}/configmaps"
PROFILES_DIR="${SKYHOOK_DIR}/profiles"
TUNED_SYSTEM_DIR="/usr/lib/tuned"
TUNED_USER_DIR="/etc/tuned"

# Read profile and provider from configmap
PROFILE_FILE="$CONFIGMAP_DIR/profile"
PROVIDER_FILE="$CONFIGMAP_DIR/provider"
TUNED_PROFILE_FILE="$CONFIGMAP_DIR/tuned_profile"

# Verify common profiles are deployed
verify_common_profiles() {
    echo "Verifying common profiles in $TUNED_SYSTEM_DIR..."
    
    if [ -d "$PROFILES_DIR/common" ]; then
        for profile_dir in "$PROFILES_DIR/common"/*/; do
            [ -d "$profile_dir" ] || continue
            profile_name=$(basename "$profile_dir")
            
            if [ ! -d "$TUNED_SYSTEM_DIR/$profile_name" ]; then
                echo "ERROR: Common profile missing: $TUNED_SYSTEM_DIR/$profile_name"
                exit 1
            fi
            
            if [ ! -f "$TUNED_SYSTEM_DIR/$profile_name/tuned.conf" ]; then
                echo "ERROR: tuned.conf missing for common profile: $profile_name"
                exit 1
            fi
            
            echo "Verified common profile: $profile_name"
        done
    fi
}

# Verify ALL OS profiles are deployed
verify_os_profiles() {
    echo "Verifying OS profiles in $TUNED_USER_DIR..."
    
    # We need to check that profiles were deployed from either OS-specific or common
    # Read OS info to determine expected source
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        local os_id="${ID:-unknown}"
        local version="${VERSION_ID:-unknown}"
        case "$os_id" in
            rhel|centos|rocky|almalinux|amzn)
                version=$(echo "$version" | cut -d. -f1)
                ;;
        esac
    fi
    
    local os_dir=""
    if [ -d "$PROFILES_DIR/os/$os_id/$version" ]; then
        os_dir="$PROFILES_DIR/os/$os_id/$version"
    elif [ -d "$PROFILES_DIR/os/common" ]; then
        os_dir="$PROFILES_DIR/os/common"
    fi
    
    if [ -n "$os_dir" ]; then
        for profile_dir in "$os_dir"/*/; do
            [ -d "$profile_dir" ] || continue
            local profile_name
            profile_name=$(basename "$profile_dir")
            
            if [ ! -d "$TUNED_USER_DIR/$profile_name" ]; then
                echo "ERROR: OS profile directory missing: $TUNED_USER_DIR/$profile_name"
                exit 1
            fi
            
            if [ ! -f "$TUNED_USER_DIR/$profile_name/tuned.conf" ]; then
                echo "ERROR: tuned.conf missing for OS profile: $profile_name"
                exit 1
            fi
            
            echo "Verified OS profile: $profile_name"
        done
    fi
}

# Verify specific workload profile exists (the one user requested)
verify_requested_profile() {
    local profile=$1
    
    if [ ! -d "$TUNED_USER_DIR/$profile" ]; then
        echo "ERROR: Requested profile directory missing: $TUNED_USER_DIR/$profile"
        exit 1
    fi
    
    if [ ! -f "$TUNED_USER_DIR/$profile/tuned.conf" ]; then
        echo "ERROR: tuned.conf missing for requested profile: $profile"
        exit 1
    fi
    
    echo "Verified requested profile: $profile"
}

# Verify provider profile is deployed with correct include
verify_provider_profile() {
    local provider=$1
    local expected_profile=$2
    
    if [ ! -d "$TUNED_USER_DIR/$provider" ]; then
        echo "ERROR: Provider profile directory missing: $TUNED_USER_DIR/$provider"
        exit 1
    fi
    
    local provider_conf="$TUNED_USER_DIR/$provider/tuned.conf"
    if [ ! -f "$provider_conf" ]; then
        echo "ERROR: tuned.conf missing for provider profile: $provider"
        exit 1
    fi
    
    # Verify include line points to correct profile
    if ! grep -q "^include=$expected_profile" "$provider_conf"; then
        echo "ERROR: Provider profile $provider does not include $expected_profile"
        echo "Contents of $provider_conf:"
        cat "$provider_conf"
        exit 1
    fi
    
    echo "Verified provider profile: $provider includes $expected_profile"
}

# Verify tuned_profile file exists and is correct
verify_tuned_profile_file() {
    local expected_profile=$1
    
    if [ ! -f "$TUNED_PROFILE_FILE" ]; then
        echo "ERROR: tuned_profile file missing: $TUNED_PROFILE_FILE"
        exit 1
    fi
    
    local actual_profile
    actual_profile=$(cat "$TUNED_PROFILE_FILE" | xargs)
    
    if [ "$actual_profile" != "$expected_profile" ]; then
        echo "ERROR: tuned_profile mismatch. Expected: $expected_profile, Got: $actual_profile"
        exit 1
    fi
    
    echo "Verified tuned_profile: $actual_profile"
}

main() {
    # Verify common profiles are deployed to /usr/lib/tuned/
    verify_common_profiles
    
    # Verify ALL OS profiles are deployed to /etc/tuned/
    verify_os_profiles
    
    # Read profile from configmap
    if [ ! -f "$PROFILE_FILE" ]; then
        echo "ERROR: Profile configmap not found at $PROFILE_FILE"
        exit 1
    fi
    PROFILE=$(cat "$PROFILE_FILE" | xargs)
    
    # Verify the requested profile exists
    verify_requested_profile "$PROFILE"
    
    # Check if provider is specified
    if [ -f "$PROVIDER_FILE" ]; then
        PROVIDER=$(cat "$PROVIDER_FILE" | xargs)
        if [ -n "$PROVIDER" ]; then
            # Verify provider profile
            verify_provider_profile "$PROVIDER" "$PROFILE"
            # Expected active profile is the provider
            verify_tuned_profile_file "$PROVIDER"
        else
            # No provider, active profile is the workload profile
            verify_tuned_profile_file "$PROFILE"
        fi
    else
        # No provider file, active profile is the workload profile
        verify_tuned_profile_file "$PROFILE"
    fi
    
    echo "Profile verification complete"
}

main "$@"
