#!/bin/bash

# Install script for Debian and Ubuntu based containers.

set -e
set -x

apt-get update
apt-get install --yes apt-transport-https curl

cat <<EOF > /etc/apt/sources.list.d/clang.list
deb http://apt.llvm.org/${DISTRIB_CODENAME}/ llvm-toolchain-${DISTRIB_CODENAME}-${CLANG_VERSION} main
deb-src http://apt.llvm.org/${DISTRIB_CODENAME}/ llvm-toolchain-${DISTRIB_CODENAME}-${CLANG_VERSION} main
EOF

cat <<EOF > /etc/apt/sources.list.d/crystal.list
deb https://dist.crystal-lang.org/apt crystal main
EOF

apt-get update

if [ ! -f /etc/lsb-release ]; then
  # Hack to detect Debian, which doesn't ship with a GPG installation.
  apt-get install gnupg --yes
fi

# apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54 15CF4D18AF4F7421
curl -sL "https://keybase.io/crystal/pgp_keys.asc" | apt-key add -

apt-get install --yes --allow-unauthenticated \
  build-essential \
  crystal libxml2-dev zlib1g-dev libncurses-dev libgc-dev libyaml-dev \
  clang-${CLANG_VERSION} libclang-${CLANG_VERSION}-dev llvm-${CLANG_VERSION}-dev libpcre3-dev
