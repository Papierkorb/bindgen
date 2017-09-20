#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"

set -x

rm -f *.o *.cpp *.cr
