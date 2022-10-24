#!/bin/sh
# Build translated version of Python Docs

[ -n "$GITHUB_ACTIONS" ] && set -x
set -e

# Allow language being passed as 1st argument, defaults to pt_BR
LANGUAGE=${1:-pt_BR}

ROOTDIR="$(dirname $0)/.."

cd "${ROOTDIR}"

if ! test -f cpython/Doc/conf.py; then
  echo Unable to find proper CPython Doc folder
  exit 1
fi

pofiles=$(find . -maxdepth 2 -name '*.po' | sort -u | sed -i 's|\./||')

for po in ${pofiles}; do
  install -Dm644 ${po} "cpython/Doc/locales/${LANGUAGE}/LC_MESSAGES/${po}"
done

sphinx-build -b html -d build/doctrees -n -a --keep-going -jauto -D locale_dirs=locales -D language=pt_BR -D gettext_compact=0 -D latex_engine=xelatex -D latex_elements.inputenc= -D latex_elements.fontenc= -W cpython/Doc cpython/Doc/build/html

if [ -z "$GITHUB_ACTIONS" ]; then
  echo 'See the built documentation by running the following command:'
  echo 'python3 -c "import os, webbrowser; webbrowser.open('file://' + os.path.realpath('cpython/Doc/build/html/index.html'))""'
fi
