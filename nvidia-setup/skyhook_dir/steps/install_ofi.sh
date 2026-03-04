#!/bin/bash -e

OFI_PREFIX=/opt/amazon/ofi-nccl
echo "PATH=\$PATH:${OFI_PREFIX}/bin" > /etc/profile.d/ofi-aws.sh
echo "${OFI_PREFIX}/lib" > /etc/ld.so.conf.d/000_ofi_aws.conf
