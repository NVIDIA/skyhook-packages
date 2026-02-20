#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
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

# The MacAdressPolicy must be set as none to avoid issue with AWS CNI plugin
# writing into /etc to avoid being overwritten by package systemd-udev
DROPIN_FOLDER=/etc/systemd/network/99-default.link.d
CONFIG_FILE=mac-address-policy.conf

mkdir -p $DROPIN_FOLDER
cat <<EOF > $DROPIN_FOLDER/$CONFIG_FILE
[Link]
MACAddressPolicy=none
EOF

# Apply bootloader settings from tuned bootcmdline
# This is needed because on AWS, tuned's bootloader settings don't automatically
# make it to grub, so we need to manually create the grub configuration
SCRIPT_DIR="/etc/tuned/aws"
if [ -f "${SCRIPT_DIR}/bootloader.sh" ]; then
    "${SCRIPT_DIR}/bootloader.sh"
fi
