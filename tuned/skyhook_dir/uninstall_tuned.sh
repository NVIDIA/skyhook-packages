#!/bin/bash
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
