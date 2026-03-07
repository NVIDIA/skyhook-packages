#!/bin/bash
# TuneD script plugin lifecycle: start | stop [full_rollback] | verify [ignore_missing]
# https://github.com/redhat-performance/tuned/blob/v2.21.0/tuned/plugins/plugin_script.py

# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

set -e

# MACAddressPolicy=none avoids issues with AWS CNI plugin; write under /etc to avoid overwrite by systemd-udev
DROPIN_FOLDER=/etc/systemd/network/99-default.link.d
CONFIG_FILE=mac-address-policy.conf
EXPECTED_NETWORK_CONTENT='[Link]
MACAddressPolicy=none
'

# Profile dir (script is in e.g. /etc/tuned/aws-{accelerator}-{intent}/)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

apply_network_dropin() {
	mkdir -p "$DROPIN_FOLDER"
	cat <<EOF > "$DROPIN_FOLDER/$CONFIG_FILE"
[Link]
MACAddressPolicy=none
EOF
}

remove_network_dropin() {
	rm -f "$DROPIN_FOLDER/$CONFIG_FILE"
	if [ -d "$DROPIN_FOLDER" ] && [ -z "$(ls -A "$DROPIN_FOLDER" 2>/dev/null)" ]; then
		rmdir "$DROPIN_FOLDER"
	fi
}

verify_network_dropin() {
	local ignore_missing=false
	[ "${2:-}" = "ignore_missing" ] && ignore_missing=true

	if [ ! -f "$DROPIN_FOLDER/$CONFIG_FILE" ]; then
		$ignore_missing && exit 0 || exit 1
	fi
	if [ "$(cat "$DROPIN_FOLDER/$CONFIG_FILE")" != "$EXPECTED_NETWORK_CONTENT" ]; then
		exit 1
	fi
	exit 0
}

run_bootloader() {
	if [ -f "${SCRIPT_DIR}/bootloader.sh" ]; then
		"${SCRIPT_DIR}/bootloader.sh"
	fi
}

cmd="${1:-}"
case "$cmd" in
	start)
		apply_network_dropin
		run_bootloader
		;;
	stop)
		remove_network_dropin
		;;
	verify)
		verify_network_dropin "$@"
		;;
	*)
		echo "Usage: $0 start | stop [full_rollback] | verify [ignore_missing]" >&2
		exit 1
		;;
esac
