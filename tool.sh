#!/bin/bash

# Helper script to invoke `bindgen.cr`

BASE="$(dirname "$(readlink -f "$0")")"

BIN_FILE="$BASE/bin/bindgen"
SOURCE_FILE="$BASE/src/bindgen.cr"

if [ -f "$BIN_FILE" ]; then
  exec "$BIN_FILE" $@
else
  exec crystal run "$SOURCE_FILE" -- $@
fi
