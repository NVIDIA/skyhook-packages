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

set -xe
set -u

source /etc/os-release
case $ID in
    ubuntu* | debian*)
        export DEBIAN_FRONTEND=noninteractive

        apt remove -y tuned && apt autoremove -y
    ;;
    centos* | redhat* | amzn*)
        yum remove -y tuned
    ;;
    fedora*)
        dnf remove -y tuned
    ;;
    *)
        echo "Unsupported Distro: $ID"
        exit 1
    ;;
esac

# disable and stop tuned service
if systemctl is-active --quiet tuned; then
    systemctl disable --now tuned
    systemctl status tuned
fi
