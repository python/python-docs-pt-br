#!/bin/sh
# Build translated docs to pop up errors
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

rootdir=$(realpath $(dirname $0)/..)

cd "$rootdir"

mkdir -p logs
touch logs/sphinxlint.txt

cd cpython/Doc/locale/${PYDOC_LANGUAGE}/LC_MESSAGES
sphinx-lint | tee $(realpath "$rootdir/logs/sphinxlint.txt")
cd $OLDPWD

# Remove empty file
if [ ! -s logs/sphinxlint.txt ]; then
  rm logs/sphinxlint.txt
fi
