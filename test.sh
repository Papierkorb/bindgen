#!/usr/bin/env bash
set -ex

run_test(){
  docker run --rm bindgen-test:$1 ci/run.sh
}

build_docker() {
  local code_name=$1
  local clang_ver=$2

  docker build . -f ci/Dockerfile.ubuntu -t bindgen-test:${code_name}-${clang_ver} --build-arg DISTRIB_CODENAME=${code_name} --build-arg CLANG_VERSION=${clang_ver}
}

build_archlinux() {
  docker build . -f ci/Dockerfile.archlinux -t bindgen-test:archlinux
}

build_images() {
  build_docker "xenial" "4.0"
  build_docker "xenial" "5.0"
  build_docker "xenial" "6.0"

  build_docker "stretch" "4.0"
  build_docker "stretch" "5.0"
  build_docker "stretch" "6.0"

  build_archlinux
}

run_tests() {
  run_test "xenial-4.0"
  run_test "xenial-5.0"
  run_test "xenial-6.0"

  run_test "stretch-4.0"
  run_test "stretch-5.0"
  run_test "stretch-6.0"

  run_test "archlinux"
}

build_images
run_tests