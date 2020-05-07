#!/usr/bin/env bash
set -ex

run_test(){
  local code_name=$1
  local clang_ver=$2
  docker run --rm bindgen-test:${code_name}-${clang_ver} ci/run.sh
}

build_docker() {
  local code_name=$1
  local clang_ver=$2

  local image="bindgen-test:${code_name}-${clang_ver}"
  docker build . -f ci/Dockerfile.ubuntu -t bindgen-test:${code_name}-${clang_ver} \
    --build-arg DISTRIB_CODENAME=${code_name} \
    --build-arg CLANG_VERSION=${clang_ver}
}

build_archlinux() {
  docker build . -f ci/Dockerfile.archlinux -t bindgen-test:archlinux
}

test_archlinux() {
  docker run --rm bindgen-test:archlinux ci/run.sh
}

for code_name in "xenial" "stretch"; do
  for clang_ver in "4.0" "5.0" "6.0"; do
    echo "${code_name}-${clang_ver}"
    build_docker ${code_name} ${clang_ver}
    run_test ${code_name} ${clang_ver}
  done
done
