#!/bin/sh
# Generate .pot files and Transifex .tx/config file
#
# SPDX-License-Identifier: CC0-1.0
#
# The following need to be set:
#   PYDOC_TX_PROJECT (e.g. python-newest)
#   PYDOC_LANGUAGE (e.g. pt_BR)
#   TX_TOKEN (or have a ~/.transifexrc file)

set -xeu

# Fail earlier if required variables are not set (do not expose TX_TOKEN)
test -n ${PYDOC_TX_PROJECT+x}
test -n ${PYDOC_LANGUAGE+x}

# Make sure to run all commands from CPython docs locales directory
cd $(dirname $0)/../cpython/Doc/locales

# Generate message catalog template (.pot) files
# TODO: use `make -C .. gettext` when there are only Python >= 3.12
opts='-E -b gettext -D gettext_compact=0 -d build/.doctrees . build/gettext' 
make -C .. build ALLSPHINXOPTS="$opts"

# Generate updated Transifex project configuration file (.tx/config)
rm -rf ./.tx/config
sphinx-intl create-txconfig
sphinx-intl update-txconfig-resources \
  --transifex-organization-name=python-doc \
  --transifex-project-name=$PYDOC_TX_PROJECT \
  --locale-dir=. \
  --pot-dir=../build/gettext

# Patch .tx/config and store in the repository to enable running tx command
# Explanation:
#  - Adds 'trans.$PYDOC_LANGUAGE' to not need to pass tx pull with '-l LANGUAGE'
#  - Don't remove 'file_filter' otherwise tx pull complains
#  - Replace PO file path to a local directory (easier manual use of tx pull)
mkdir -p "${PYDOC_LANGUAGE}/LC_MESSAGES/.tx/"
sed .tx/config \
  -e 's|./<lang>/LC_MESSAGES/||' \
  -e "/^file_filter/{p;s/file_filter/trans.${PYDOC_LANGUAGE}/g;}" \
	> "${PYDOC_LANGUAGE}/LC_MESSAGES/.tx/config"
