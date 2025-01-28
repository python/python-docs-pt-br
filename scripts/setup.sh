#!/bin/sh
# Set up environment for operations on Python docs translation
# This is meant for running locally to make it easier to test etc.
#
# SPDX-License-Identifier: CC0-1.0

set -xeu

# Fail earlier if required variables are not set
test -n ${PYDOC_VERSION+x}
test -n ${PYDOC_REPO+x}
test -n ${PYDOC_LANGUAGE+x}

# Make sure to run all commands from repository root directory
cd $(dirname $0)/..

# Clean up
rm -rf cpython

# Check out needed repositories
git clone --depth 1 --single-branch --branch ${PYDOC_VERSION} https://github.com/python/cpython cpython
git clone --depth 1 --single-branch --branch ${PYDOC_VERSION} ${PYDOC_REPO} cpython/Doc/locales/${PYDOC_LANGUAGE}/LC_MESSAGES

# Install dependencies; Require being in a VENV or in GitHub Actions
set +u
if [ -z "${VIRTUAL_ENV+x}" ] && [ -z "${CI+x}" ]; then
  echo "Expected to be in a virtual environment. For instance:"
  echo "   rm -rf .venv && python -m venv .venv && source ~/venv/bin/activate"
  exit 1
fi
set -u
pip install -r requirements.txt
make -C cpython/Doc venv


if [[ ${PYDOC_VERSION} == '3.7' ]]; then
  # Fixes circular dependencies that affects Python 3.7, see:
  #   https://github.com/sphinx-doc/sphinx/issues/11567
  #   https://github.com/bazelbuild/rules_python/pull/1166
  cpython/Doc/venv/bin/pip install \
    sphinxcontrib-applehelp==1.0.4 \
    sphinxcontrib-devhelp==1.0.2 \
    sphinxcontrib-htmlhelp==2.0.1 \
    sphinxcontrib-qthelp==1.0.3 \
    sphinxcontrib-serializinghtml==1.1.5 \
    alabaster==0.7.13
  # Add missing sections to satisfy Blurb's check
  curl -L https://github.com/python/cpython/pull/114553.patch -o ../../114553.patch
  git apply ../../114553.patch
fi

if ! command -v tx > /dev/null; then
  echo "WARNING: Transifex CLI tool was not found."
  echo "If going to pull translations it is needed, can be ignored otherwise."
  echo "See https://github.com/transifex/cli for install info" 
fi
