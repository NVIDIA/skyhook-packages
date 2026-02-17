#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
KERNEL_VERSION="${1:?kernel version required}"
LUSTRE="${2:-aws}"
# shellcheck source=../utilities.sh
. "${SKYHOOK_DIR}/utilities.sh"

install_from_aws() {
  local KVER="$1"
  local FULL_KERNEL_VER
  FULL_KERNEL_VER="$(resolve_full_kernel "${KVER}")"
  mkdir -m 0755 -p /etc/apt/keyrings/
  wget -q -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc \
    | gpg --dearmor -o /etc/apt/keyrings/fsx-ubuntu-public-key.gpg
  chmod -R 0755 /etc/apt/keyrings
  echo "deb [signed-by=/etc/apt/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu jammy main" \
    | tee /etc/apt/sources.list.d/fsxlustreclientrepo.list > /dev/null && apt-get update
  echo "Installing lustre from AWS repo for kernel ${FULL_KERNEL_VER} ..."
  if apt-cache show "lustre-client-modules-${FULL_KERNEL_VER}" >/dev/null 2>&1; then
    apt install -y "lustre-client-modules-${FULL_KERNEL_VER}"
  else
    lustre_package=$(apt-cache search "lustre-client-modules-${KVER}" | sort -r | awk '{print $1; exit}')
    apt install -y "${lustre_package}"
  fi
}

build_from_source() {
  local KVER="$1"
  local LUSTRE_REF="$2"
  local FULL_KERNEL_VER
  FULL_KERNEL_VER="$(resolve_full_kernel "${KVER}")"
  local HEADERS_PATH="/usr/src/linux-headers-${FULL_KERNEL_VER}"
  echo "Building lustre '${LUSTRE_REF}' for kernel ${FULL_KERNEL_VER} ..."
  apt-get update
  BUILD_DEPS="flex bison libyaml-dev libyaml-cpp-dev libnl-3-dev libnl-genl-3-dev \
libreadline-dev pkg-config git gcc-12 g++-12 libtool quilt automake autoconf \
module-assistant debhelper rsync libpython3-dev swig libext2fs-dev libkeyutils-dev libaio-dev \
libmount-dev libssl-dev libselinux1-dev linux-headers-generic build-essential"
  REMOVE_DEPS=""
  for pkg in ${BUILD_DEPS}; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      REMOVE_DEPS="${REMOVE_DEPS} ${pkg}"
    fi
  done
  apt-get install -y -o DPkg::Lock::Timeout=60 --no-install-recommends \
    -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" ${BUILD_DEPS}
  DEST="$(mktemp -d -t lustre.XXXXXXXX)" || DEST="/tmp/lustre.$$"
  trap 'rm -rf "$DEST"' EXIT
  export DEST CC=gcc-12 CXX=g++-12
  mkdir -p "${DEST}" && cd "${DEST}"
  git clone -b "${LUSTRE_REF}" --single-branch https://github.com/lustre/lustre-release.git
  cd lustre-release
  sh autogen.sh
  ./configure --with-linux="${HEADERS_PATH}" --disable-server
  make -j"$(nproc)" debs
  dpkg -i debs/lustre-client-modules-${FULL_KERNEL_VER}_*.deb
  if [ -n "${REMOVE_DEPS// }" ]; then
    apt-get purge -y ${REMOVE_DEPS}
  fi
}

if [ "${LUSTRE}" = "aws" ]; then
  install_from_aws "${KERNEL_VERSION}"
else
  build_from_source "${KERNEL_VERSION}" "${LUSTRE}"
fi
