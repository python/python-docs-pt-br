#!/bin/sh
# Commit changed files filtering to the git repository
#
# SPDX-License-Identifier: CC0-1.0

set -eu

cd $(dirname $0)/../cpython/Doc/locales/${PYDOC_LANGUAGE}/LC_MESSAGES

extra_files=".tx/config stats.json potodo.md"

set +u
if [ -n "${CI+x}" ]; then
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"
fi
set -u

# Set for removal the deleted obsolete PO files
git status -s | grep '^ D ' | cut -d' ' -f3 | xargs -r git rm

# Add only updates that do not consist only of 'POT-Creation-Date' header change
git diff -I'^"POT-Creation-Date: ' -I'^"Language: pt_BR' --numstat *.po **/*.po | cut -f3 | xargs -r git add -v

# Add currently untracked PO files, and update other helper files
untracked_files=$(git ls-files -o --exclude-standard *.po **/*.po)
if [ -n "${untracked_files+x}" ]; then
  git add -v $untracked_files
fi

# Debug in GitHub Actions
set +u
if [ -n "${CI+x}" ]; then
  echo "::group::status"
  git status
  echo "::endgroup::"
  echo "::group::diff"
  git diff
  echo "::endgroup::"
fi
set -u

# Commit only if there is any cached file
git diff-index --cached --quiet HEAD || { git add -v $extra_files; git commit -vm "Update translations"; }
