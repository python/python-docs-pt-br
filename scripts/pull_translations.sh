#!/bin/sh
# Pull translations files from Transifex for the given language code
#
# SPDX-License-Identifier: CC0-1.0
#
# Usage examples:
#
#  Pull all translations for the given language.
#
#     ./scripts/pull_translations.sh
#
#  Pull translations for "library/os.po" and "faq/library.po"
#  for the Transifex project set in PYDOC_TX_PROJECT. For instance,
#  for PYDOC_TX_PROJECT=python-newest, that means pulling the resources
#  "python-newest.library--os" and "python-newest.faq--library".
#
#     ./scripts/pull_translations.sh  library/os.po  faq/library.po
#

set -xeu

test -n ${PYDOC_LANGUAGE+x}
test -n ${PYDOC_TX_PROJECT+x}

cd "$(dirname $0)/../cpython/Doc/locale/${PYDOC_LANGUAGE}/LC_MESSAGES/"

# If a PO file is provided as input, convert it into Transifex resource
# and add it be pulled (instead of pulling all translations files).
resources_to_pull=""
if [ $# -gt 0 ]; then
  resources_to_pull="-r"
  for po_input in $@; do
    # trim possible filepath part not used for Transifex resources
    po=$(echo $po_input | sed 's|.*LC_MESSAGES/||')
    # fail if PO file doesn't exist
    [ ! -f "$po" ] && (echo "'$po_input' not found."; exit 1;)
    # convert po filename into transifex resource
    tx_res=$(echo $po | sed 's|\.po||;s|/|--|g;s|\.|_|g')
    # append to a list of resources to be pulled
    resources_to_pull="$resources_to_pull ${PYDOC_TX_PROJECT}.${tx_res}"
  done
fi

tx pull -f -l "${PYDOC_LANGUAGE}" ${resources_to_pull}
