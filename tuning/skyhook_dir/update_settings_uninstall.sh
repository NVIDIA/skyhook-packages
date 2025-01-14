#!/bin/bash

#  SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#  SPDX-License-Identifier: Apache-2.0

set -e


if [ ${SET_X:-0} -eq 1 ]; then
    set -x
fi

# SKYHOOK_RESOURCE_ID is {id}_{package name}_{version}
# We want to use the package name in the drop in files so multiple tuning packages can be installed
package_name=$(echo ${SKYHOOK_RESOURCE_ID} | cut -f 2 -d _)

if [ -f /etc/sysctl.d/999-${package_name}-tuning.conf ]; then
    rm /etc/sysctl.d/999-${package_name}-tuning.conf
fi

if [ -f /etc/security/limits.d/999-${package_name}-tuning.conf ]; then
    rm /etc/security/limits.d/999-${package_name}-tuning.conf
fi

# remove any service drop in files that may have been created
rm /etc/systemd/system/*.d/999-${package_name}-tuning.conf

if [ -f /etc/default/grub.d/999-${package_name}-tuning.cfg ]; then
    rm /etc/default/grub.d/999-${package_name}-tuning.cfg
fi