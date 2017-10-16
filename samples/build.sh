#!/bin/bash

# Script to build the samples.
# Run without arguments to build all samples.
# Run with an argument to build a single sample.

set -e

if (( $# < 1 )); then
  for file in *.yml; do
    printf "Building sample %s\n" "${file}"
    $0 $file
  done
else
  mkdir -p binding

  cd ..
  exec ./tool.sh --chdir samples $@
fi
