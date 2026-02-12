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
#   GITHUB_OUTPUT - If set, outputs are written to this file (GitHub Actions)

set -e

# Check if PACKAGE_VERSIONS is set
if [ -z "${PACKAGE_VERSIONS:-}" ]; then
    echo "ERROR: PACKAGE_VERSIONS environment variable is not set"
    exit 1
fi

# Extract the tuned version from the JSON
latest_version=$(jq -r '.tuned' <<< "${PACKAGE_VERSIONS}")

# Check if the version was found
if [ -z "${latest_version}" ] || [ "${latest_version}" = "null" ]; then
    echo "ERROR: Could not find 'tuned' package version in PACKAGE_VERSIONS: ${PACKAGE_VERSIONS}"
    exit 1
fi

echo "Found tuned version: ${latest_version}"

# Output the build args
# If running in GitHub Actions, write to GITHUB_OUTPUT
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "BUILD_ARGS=TUNED_VERSION=${latest_version}" >> "$GITHUB_OUTPUT"
else
    # For local testing, output to stdout
    echo "BUILD_ARGS=TUNED_VERSION=${latest_version}"
fi