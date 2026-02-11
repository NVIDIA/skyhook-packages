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

# Preprocess script for nvidia_tuned package
# Fetches the most recent tag for the tuned package and outputs it as TUNED_VERSION
#
# This script outputs GitHub Actions environment variables in the format:
#   BUILD_ARGS=TUNED_VERSION=<version>
#
# Usage: ./preprocess.sh
# Environment variables:
#   GITHUB_TOKEN - Optional, used for authenticated API requests (higher rate limit)
#   GITHUB_OUTPUT - If set, outputs are written to this file (GitHub Actions)

set -e

# Configuration
# GITHUB_REPOSITORY is set automatically in GitHub Actions (e.g., "nvidia/skyhook-packages")
# For local testing, default to the expected repository
REPO="${GITHUB_REPOSITORY:-nvidia/skyhook-packages}"
PACKAGE_NAME="tuned"

# Fetch the latest tag for the tuned package from GitHub repository tags
get_latest_tuned_tag() {
    local api_url="https://api.github.com/repos/${REPO}/tags"
    local auth_header=""
    
    # Use GITHUB_TOKEN if available for higher rate limits
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header="Authorization: Bearer ${GITHUB_TOKEN}"
    fi
    
    # Fetch repository tags from GitHub API
    local response
    if [ -n "$auth_header" ]; then
        response=$(curl -s -H "$auth_header" -H "Accept: application/vnd.github+json" "$api_url")
    else
        response=$(curl -s -H "Accept: application/vnd.github+json" "$api_url")
    fi
    
    # Check for API errors
    if echo "$response" | grep -q '"message"'; then
        local error_msg
        error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | head -1)
        echo "ERROR: GitHub API error: $error_msg" >&2
        echo "ERROR: Unable to fetch tags for ${REPO}" >&2
        return 1
    fi
    
    # Extract tags that match the pattern "tuned/X.Y.Z" and get the version part
    # Then sort semantically and return the latest
    local latest_tag
    latest_tag=$(echo "$response" | \
        grep -oE "\"name\":\s*\"${PACKAGE_NAME}/[0-9]+\.[0-9]+\.[0-9]+\"" | \
        grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | \
        sort -t. -k1,1n -k2,2n -k3,3n | \
        tail -1)
    
    if [ -z "$latest_tag" ]; then
        echo "ERROR: No valid tags found matching pattern '${PACKAGE_NAME}/X.Y.Z'" >&2
        return 1
    fi
    
    echo "$latest_tag"
}

main() {
    echo "Fetching latest tag for ${PACKAGE_NAME} from ${REPO}..." >&2
    
    local latest_version
    latest_version=$(get_latest_tuned_tag)
    
    if [ -z "$latest_version" ]; then
        echo "ERROR: Failed to determine latest version" >&2
        exit 1
    fi
    
    echo "Found latest ${PACKAGE_NAME} version: ${latest_version}" >&2
    
    # Output the build args
    # If running in GitHub Actions, write to GITHUB_OUTPUT
    if [ -n "${GITHUB_OUTPUT:-}" ]; then
        echo "BUILD_ARGS=TUNED_VERSION=${latest_version}" >> "$GITHUB_OUTPUT"
    else
        # For local testing, output to stdout
        echo "BUILD_ARGS=TUNED_VERSION=${latest_version}"
    fi
}

main "$@"
