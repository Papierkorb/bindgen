#!/bin/bash

# Helper script to invoke `bindgen.cr`

BASE="$(dirname "$(readlink -f "$0")")"

CLANG_DIR="$BASE/clang/"
SOURCE_FILE="$BASE/src/bindgen.cr"

function print_clang_error {
  echo "  Bindgen requires a full installation of Clang, its libraries and development"
  echo "  headers.  Please install these first, and restart this script."
  echo "  You can also manually run 'make' in clang/ for debugging this issue."
  echo "  Full path to clang/: $CLANG_DIR"

  exit 1
}

if [ ! -f "$CLANG_DIR/bindgen" ]; then
  echo "** clang/bindgen not found.  Building now."
  cd "$CLANG_DIR"
  make || print_clang_error
  cd -
fi

OLD_PWD="$PWD"
cd "$BASE"

if [[ "$@" == *"--chdir"* ]]; then
  exec crystal run "$SOURCE_FILE" -- $@
else
  exec crystal run "$SOURCE_FILE" -- --chdir "$OLD_PWD" $@
fi

echo 'If you see this, something went horribly wrong.'
echo '  1) Make sure you have crystal installed'
echo '  2) Make sure `crystal` is in your $PATH'
exit 127
