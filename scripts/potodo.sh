#!/bin/sh
# Extract the list of incomplete translation files.
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

# Fail earlier if required variables are not set
test -n ${PYDOC_VERSION+x}
test -n ${PYDOC_LANGUAGE+x}

rootdir=$(realpath $(dirname $0)/..)

cd "$rootdir"/cpython/Doc/locales/${PYDOC_LANGUAGE}/LC_MESSAGES

potodo --no-cache > potodo.md

# Show version number instead of the directory name, if present
sed -i "s|LC_MESSAGES|${PYDOC_VERSION}|" potodo.md

# Remove total for now as it only consider incomplete files.
# https://git.afpy.org/AFPy/potodo/issues/7
sed -i "/^# TOTAL /d" potodo.md

# Remove cache directory
rm -rf .potodo/
