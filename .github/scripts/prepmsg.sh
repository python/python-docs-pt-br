#!/bin/bash
# Prepare message for Telegram notification
set -ex

die() { echo "$0: error: $*" >&2; exit 1; }

[ $# -ne 2 ] && die "Expected 1 input and 1 output files, got $#"
[ ! -f "$1" ]  && die "Input file $1 not found, skipping."
[ -z "${GITHUB_REPOSITORY}" ] && die "GITHUB_REPOSITORY is empty."
[ -z "${GITHUB_RUN_ID}" ] && die "GITHUB_RUN_ID is empty."
[ -z "${GITHUB_JOB}" ] && die "GITHUB_JOB is empty."

URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

input="$1"
output="$2"

touch aux
if [[ "${GITHUB_JOB}" == "build" ]]; then
    grep 'cpython/Doc/.*WARNING:' "$input" | \
          sed 's|.*/cpython/Doc/||' | \
          uniq | \
          sed 's|^|```\n|;s|$|\n```\n|' \
          > aux
elif [[ "${GITHUB_JOB}" == "lint" ]]; then
    grep -P '^.*\.po:\d+:\s+.*\(.*\)$' "$input" | \
          sort -u | \
          sed 's|^|```\n|;s|$|\n```\n|' \
          > aux
else
    die "Unexpected job name ${GITHUB_JOB}"
fi

[[ $(cat aux) == "" ]] && die "Unexpected empty output message."

echo "❌ *${GITHUB_JOB}* (ID&nbsp;[${GITHUB_RUN_ID}]($URL)):" > "$output";
{ echo ""; cat aux; echo ""; } >> "$output"
rm aux
