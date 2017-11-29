# Dockerfile for bindgen, used for automated testing on travis-ci.org

FROM base/devel

COPY . /

RUN pacman -Syu --noconfirm llvm clang crystal shards gc libyaml
RUN make -C clang
