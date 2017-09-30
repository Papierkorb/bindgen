#!/bin/bash

set -x

for file in *.dot; do
  dot -Tpng $file > ${file/.dot/.png}
done
