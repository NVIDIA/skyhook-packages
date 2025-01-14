#!/bin/bash

#  SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
#  SPDX-License-Identifier: Apache-2.0

if [ ${SET_X:-0} -eq 1 ]; then
set -x
fi

failures=""

if [ -f ${SKYHOOK_DIR}/configmaps/sysctl.conf ]; then
    echo "-------------------------"
    echo "Checking sysctl settings"
    echo "-------------------------"
    while IFS= read -r line
    do
        name=$(echo $line | cut -f 1 -d =)
        exp_value=$(echo $line | cut -f 2 -d =)
        value=$(sysctl $name | cut -f 2 -d =)
        if [ $exp_value != $value ]; then
            failures=$(printf "%s\n%s" "${failures}" "$name:  ${exp_value} != ${value}")
        fi
    done  <<< $(cat ${SKYHOOK_DIR}/configmaps/sysctl.conf)
fi

if [[ -f ${SKYHOOK_DIR}/configmaps/service_containerd.conf || -f ${SKYHOOK_DIR}/configmaps/service_crio.conf ]]; then
    echo "-------------------------"
    echo "Check container limits"
    echo "-------------------------"
    while IFS= read -r line
    do
        name=$(echo $line | cut -f 1 -d = | sed 's/Limit//g')
        expected_value=$(echo $line | cut -f 2 -d =)
        if [ ${expected_value} == "infinity" ]; then
            continue
        fi
        case $name in
            "NOFILE")
                actual_value=$(ulimit -n)
            ;;
            "FSIZE")
                actual_value=$(ulimit -f)
            ;;
            "STACK")
                actual_value=$(ulimit -s)
                # The value is actually 1024 of the expected value due to being in KB
                expected_value=$((${expected_value} / 1024))
            ;;
            "NPROC")
                actual_value=$(ulimit -u)
            ;;
            "MEMLOCK")
                actual_value=$(ulimit -l)
                # The value is actually 1024 of the expected value due to being in KB
                if [ ${expected_value} != "infinity" ]; then
                    expected_value="infinity"
                else
                    expected_value=$((${expected_value} / 1024))
                fi
            ;;
            *)
            echo "Unkown setting ${name}"
            ;;
        esac
        if [ ${expected_value} != ${actual_value} ]; then
            failures=$(printf "%s\n%s" "${failures}" "$name: ${expected_value} != ${actual_value}")
        fi
    # Use cat here instead of < file in case of single line files
    done <<< $(cat ${SKYHOOK_DIR}/configmaps/container_limits.conf)
fi

if [ -f ${SKYHOOK_DIR}/configmaps/grub.conf ]; then
    echo "-------------------------"
    echo "Checking grub settings"
    echo "-------------------------"
    grub_update=""
    while IFS= read -r line
    do
        grub_update="${grub_update} ${line}"
    done <<< $(cat ${SKYHOOK_DIR}/configmaps/grub.conf)
    if [ $(grep -c "${grub_update}" /proc/cmdline) -eq 0 ]; then
        failures=$(printf "%s\n%s" "${failures}" "${grub_update} NOT in kernel cmdline: $(cat /proc/cmdline)")
    fi
fi

if [ -n "$failures" ]; then
    echo "${failures}"
    exit 1
fi