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

if ! command -v tx > /dev/null; then
  echo "WARNING: Transifex CLI tool was not found."
  echo "If going to pull translations it is needed, can be ignored otherwise."
  echo "See https://github.com/transifex/cli for install info" 
fi
