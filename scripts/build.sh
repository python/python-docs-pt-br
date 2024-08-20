#!/bin/sh
# Build translated docs to pop up errors
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

cd "$(dirname $0)/.."
mkdir -p logs
opts="-D gettext_compact=False -D language=${PYDOC_LANGUAGE} --keep-going -w ../../logs/sphinxwarnings.txt"
make -C cpython/Doc html SPHINXOPTS="${opts}"

# Remove empty file
if [ ! -s logs/sphinxwarnings.txt ]; then
  rm logs/sphinxwarnings.txt
fi
