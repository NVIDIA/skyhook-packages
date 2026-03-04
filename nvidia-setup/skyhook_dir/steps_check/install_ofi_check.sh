#!/bin/bash

if [ ! -f /etc/profile.d/ofi-aws.sh ]; then
  echo "ERROR: /etc/profile.d/ofi-aws.sh not found"
  exit 1
fi

if [ ! -f /etc/ld.so.conf.d/000_ofi_aws.conf ]; then
  echo "ERROR: /etc/ld.so.conf.d/000_ofi_aws.conf not found"
  exit 1
fi

if [ ! -d /opt/amazon/ofi-nccl ]; then
  echo "ERROR: /opt/amazon/ofi-nccl not found"
  exit 1
fi
