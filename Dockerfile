# Dockerfile for bindgen, used for automated testing on travis-ci.org

FROM ubuntu:16.04

ARG CLANG_VERSION=5.0

COPY . /

RUN echo ' \
  deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main \n\
  deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-4.0 main \n\
  deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main \n\
  deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-5.0 main \n\
  ' > /etc/apt/sources.list.d/clang.list

RUN \
  apt-get update && \
  apt-get install --yes apt-transport-https && \
  apt-key adv --keyserver keys.gnupg.net --recv-keys 09617FD37CC06B54 && \
  echo "deb https://dist.crystal-lang.org/apt crystal main" > /etc/apt/sources.list.d/crystal.list && \
  apt-get update && \
  apt-get install --yes --allow-unauthenticated \
    build-essential \
    crystal libxml2-dev zlib1g-dev libncurses-dev libgc-dev libyaml-dev \
    clang-$CLANG_VERSION libclang-$CLANG_VERSION-dev llvm-$CLANG_VERSION-dev libpcre3-dev

RUN make -C clang
