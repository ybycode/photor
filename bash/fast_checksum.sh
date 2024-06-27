#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  >&2 echo "USAGE: $0 --help"
  >&2 echo "USAGE: $0 FILE NBYTES"
  exit 1
fi

if [[ "$1" = "--help" ]]; then
  >&2 echo "help"
  exit 0
fi

filename="$1"
nbytes="$2"
filesize="$(stat --printf="%s" "$filename")"

cat <(echo -n "$filesize") <(head --bytes $nbytes "$filename") \
  | sha256sum \
  | awk '{ print $1 }'
