#!/bin/bash
set -xe
set -u

source /etc/os-release
case $ID in
    ubuntu* | debian*)
        export DEBIAN_FRONTEND=noninteractive

        apt update -y && apt upgrade -y
        apt install -o DPKG::Lock::Timeout=60 -y tuned
    ;;
    centos* | redhat* | amzn*)
        yum update -y
        yum install -y tuned
    ;;
    fedora*)
        dnf upgrade -y
        dnf install -y tuned
    ;;
    *)
        echo "Unsupported Distro: $ID"
        exit 1
    ;;
esac

# enable tuned service
systemctl enable --now tuned
systemctl status tuned
