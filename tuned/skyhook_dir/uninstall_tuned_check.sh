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

set -x

# wait for tuned
sleep 1

# ensure that tuned is uninstalled
if command -v tuned >/dev/null 2>&1; then
    echo "ERROR: tuned is still installed."
    exit 1
fi

# ensure that tuned-adm is uninstalled
if command -v tuned-adm >/dev/null 2>&1; then
    echo "ERROR: tuned-adm is still installed."
    exit 1
fi

# ensure that the tuned service is stopped
if systemctl is-active --quiet tuned; then
    echo "ERROR: tuned is still running"
    exit 1
fi

# ensure that the tuned service is disabled
if systemctl is-enabled --quiet tuned; then
    echo "ERROR: tuned is still enabled at boot"
    exit 1
fi
