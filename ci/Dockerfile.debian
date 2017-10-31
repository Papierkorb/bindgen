# Dockerfile for bindgen, used for automated testing on travis-ci.org

FROM debian:stretch
ARG CLANG_VERSION=5.0
ARG DISTRIB_CODENAME=stretch

COPY . /

RUN ci/install_debian.sh
RUN make -C clang
