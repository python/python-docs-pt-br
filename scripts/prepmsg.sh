#!/bin/sh
# Prepare message for Telegram notification
set -ex

[ $# -ne 2 ] && ( echo "Expected 1 input and 1 output files, got $#"; exit; )
[ ! -f $1 ]  && ( echo "Input file $1 not found, skipping."; exit; )
[ -z "${GITHUB_REPOSITORY}" ] && (echo "GITHUB_REPOSITORY is empty."; exit 1;)
[ -z "${GITHUB_RUN_ID}" ] && (echo "GITHUB_RUN_ID is empty."; exit 1;)
[ -z "${GITHUB_JOB}" ] && (echo "GITHUB_JOB is empty."; exit 1;)

URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

echo "❌ *${GITHUB_JOB}* (ID&nbsp;[${GITHUB_RUN_ID}]($URL)):" > $2
echo "" >> $2
grep 'cpython/Doc/.*WARNING:' $1 | \
      sed 's|.*/cpython/Doc|Doc|' | \
      uniq | \
      sed 's|^|```\n|;s|$|\n```\n|' \
      >> $2
echo "" >> $2
