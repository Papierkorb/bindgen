#!/bin/bash

# Install script for Debian and Ubuntu based containers.

set -e
set -x

apt-get update
apt-get install --yes apt-transport-https

cat <<EOF > /etc/apt/sources.list.d/clang.list
deb http://apt.llvm.org/${DISTRIB_CODENAME}/ llvm-toolchain-${DISTRIB_CODENAME}-${CLANG_VERSION} main
deb-src http://apt.llvm.org/${DISTRIB_CODENAME}/ llvm-toolchain-${DISTRIB_CODENAME}-${CLANG_VERSION} main
EOF

cat <<EOF > /etc/apt/sources.list.d/crystal.list
deb https://dist.crystal-lang.org/apt crystal main
EOF

apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54

apt-get update
apt-get install --yes --allow-unauthenticated \
  build-essential \
  crystal libxml2-dev zlib1g-dev libncurses-dev libgc-dev libyaml-dev \
  clang-${CLANG_VERSION} libclang-${CLANG_VERSION}-dev llvm-${CLANG_VERSION}-dev libpcre3-dev
