#!/usr/bin/env bash

set -euo pipefail

help() {
  >&2 echo "
  This calculates the sha256sum of the size and first NBYTES of a given file

  USAGE: $0 --help
         $0 FILE NBYTES

  EXAMPLES:

    \$ $0 <(echo 123) 2
    d4c2ea3c5f634412ee2da81444992bcf2ff866675fddc79a39a185480c635848

    \$ $0 ./some/file 512
    cae86a3ba19a5d86a95c79415be79b6551982d92c62a6d1c15926033f200ca8d"
}

if [[ $# = 1 ]] && [[ "$1" = "--help" ]]; then
  help
  exit 0
fi

if [[ $# -ne 2 ]]; then
  help
  exit 1
fi

filename="$1"
nbytes="$2"
filesize="$(stat --printf="%s" "$filename")"

cat <(echo -n "$filesize") <(head --bytes "$nbytes" "$filename") \
  | sha256sum \
  | awk '{ print $1 }'
