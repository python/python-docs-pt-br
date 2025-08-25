#!/bin/sh
# Build translated docs to pop up errors
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

# Fail earlier if required variables are not set
test -n ${PYDOC_LANGUAGE+x}

# Fail earlier if sphinx-lint is not installed
sphinx-lint --help >/dev/null

rootdir=$(realpath $(dirname $0)/..)

cd "$rootdir"

mkdir -p logs
touch logs/sphinxlint.txt

cd cpython/Doc

# If version 3.11 or older, disable new 'unnecessary-parentheses' check,
# not fixed before 3.12.
minor_version=$(git branch --show-current | sed 's|^3\.||')
if [ $minor_version -le 11 ]; then
  alias sphinx-lint='sphinx-lint --disable unnecessary-parentheses'
fi

cd locales/${PYDOC_LANGUAGE}/LC_MESSAGES
set +e
sphinx-lint 2> $(realpath "$rootdir/logs/sphinxlint.txt")
set -e

cd "$rootdir"

# Check of logfile is empty
if [ ! -s logs/sphinxlint.txt ]; then
  # OK, it is empty. Remove it.
  rm logs/sphinxlint.txt
else
  # print contents and exit with error status (to trigger notification in CI)
  cat logs/sphinxlint.txt
  exit 1
fi
