#!/bin/sh
# Build translated docs to pop up errors
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

# Fail earlier if required variables are not set
test -n ${PYDOC_LANGUAGE+x}

cd "$(dirname $0)/.."
mkdir -p logs

# If version is 3.12 or older, set gettext_compact.
# This confval is not needed since 3.12.
# In 3.13, its presence messes 3.13's syntax checking (?)
opts="-D language=${PYDOC_LANGUAGE} --keep-going -w ../../logs/sphinxwarnings.txt"
minor_version=$(git -C cpython/Doc branch --show-current | sed 's|^3\.||')
if [ $minor_version -lt 12 ]; then
  opts+='-D gettext_compact=False'
fi

make -C cpython/Doc html SPHINXOPTS="${opts}"

# Remove empty file
if [ ! -s logs/sphinxwarnings.txt ]; then
  rm logs/sphinxwarnings.txt
fi
