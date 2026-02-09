#!/bin/bash

# The MacAdressPolicy must be set as none to avoid issue with AWS CNI plugin
# writing into /etc to avoid being overwritten by package systemd-udev
DROPIN_FOLDER=/etc/systemd/network/99-default.link.d
CONFIG_FILE=mac-address-policy.conf

mkdir -p $DROPIN_FOLDER
cat <<EOF > $DROPIN_FOLDER/$CONFIG_FILE
[Link]
MACAddressPolicy=none
EOF
