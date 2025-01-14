#!/bin/bash

#  SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#  SPDX-License-Identifier: Apache-2.0

set -e

if [ ${SET_X:-0} -eq 1 ]; then
    set -x
fi

failures=""
for f in $(find /etc -name 999-skyhook-tuning.conf); do
    failures=$(printf "%s\n%s" "$failures" "$f still exists")
done

if [ -n "$failures" ]; then
    echo "${failures}"
    exit 1
fi