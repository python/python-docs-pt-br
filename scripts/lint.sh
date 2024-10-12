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

# Disable literal blocks and update PO
sed -i "/^\s*'literal-block',/s/ '/ #'/" conf.py
# TODO: use `make -C .. gettext` when there are only Python >= 3.12
opts='-E -b gettext -q -D gettext_compact=0 -d build/.doctrees . build/gettext' 
make build ALLSPHINXOPTS="$opts"
# Update translation files with latest POT
sphinx-intl update -d locale -p build/gettext -l pt_BR > /dev/null

cd locale/${PYDOC_LANGUAGE}/LC_MESSAGES
sphinx-lint | tee $(realpath "$rootdir/logs/sphinxlint.txt")

# Undo changes that disabled literal blocks
git checkout *.po

cd "$rootdir"

# Remove empty file
if [ ! -s logs/sphinxlint.txt ]; then
  rm logs/sphinxlint.txt
fi
