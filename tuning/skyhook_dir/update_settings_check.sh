#!/bin/bash

#  SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#  SPDX-License-Identifier: Apache-2.0

if [ ${SET_X:-0} -eq 1 ]; then
set -x
fi

# SKYHOOK_RESOURCE_ID is {id}_{package name}_{version}
# We want to use the package name in the drop in files so multiple tuning packages can be installed

# NOTE: Package name is also in: jq -r ${SKYHOOK_DIR}/config.json .package_name
#       But that would require jq to be installed AND it would always be tuning
#       no matter if the package name in the SCR was different
#       which could cause conflicts if multiple tuning packages are installed
package_name=$(echo ${SKYHOOK_RESOURCE_ID} | cut -f 2 -d _)

failures=""

if [ -f ${SKYHOOK_DIR}/configmaps/sysctl.conf ]; then
    while IFS= read -r line
    do
        if [ $(grep -c "${line}" /etc/sysctl.d/999-${package_name}-tuning.conf) -eq 0 ]; then
            failures=$(printf "%s\n%s" "$failures" "not in sysctl: ${line}")
        fi
    done  <<< $(cat ${SKYHOOK_DIR}/configmaps/sysctl.conf)
fi

if [ -f ${SKYHOOK_DIR}/configmaps/ulimit.conf ]; then
    while IFS= read -r line
    do
        if [ $(grep -c "${line}" /etc/security/limits.d/999-${package_name}-tuning.conf) -eq 0 ]; then
            failures=$(printf "%s\n%s" "$failures" "No ${line} setting in /etc/security/limits.d/999-${package_name}-tuning.conf")
        fi
    done  <<< $(cat ${SKYHOOK_DIR}/configmaps/ulimit.conf)
fi

if [ -n "$failures" ]; then
    echo "${failures}"
    exit 1
fi