#!/bin/bash

#  SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#  SPDX-License-Identifier: Apache-2.0

file=$1

if [ -f ${SKYHOOK_DIR}/configmaps/${file}.sh ]; then
    . ${SKYHOOK_DIR}/configmaps/${file}.sh
else
    echo "Could not find file ${SKYHOOK_DIR}/configmaps/${file}.sh was this in the configmap?"
fi
