#!/bin/sh
# Pull catalog message files from Transifex

[ -n "$GITHUB_ACTIONS" ] && set -x
set -e

# Allow language being passed as 1st argument, defaults to pt_BR
LANGUAGE=${1:-pt_BR}

ROOTDIR=$(realpath "$(dirname $0)/..")

cd ${ROOTDIR}

if ! test -f cpython/Doc/conf.py; then
  echo Unable to find proper CPython Doc folder
  exit 1
fi

# Create POT Files
cd cpython/Doc
sphinx-build -E -b gettext -D gettext_compact=0 -d build/.doctrees . locales/pot

# Update CPython's .tx/config
cd  locales
sphinx-intl create-txconfig
sphinx-intl update-txconfig-resources -p pot -d . --transifex-organization-name python-doc --transifex-project-name python-newest

# Pull translations into cpython/Doc/locales/LANGUAGE/LC_MESSAGES/
tx pull -l ${LANGUAGE} -t --use-git-timestamps -f

# Finally, move downloaded translation files to the language's repository
cd "${LANGUAGE}/LC_MESSAGES/"
for po in $(find . -type f -name '*.po' | sort | sed 's|^\./||'); do
  install -Dm644 ${po} "${ROOTDIR}/${po}"
done
