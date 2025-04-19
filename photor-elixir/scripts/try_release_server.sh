#!/usr/bin/env bash

# Runs the server command of the last release, to try it out locally.
# NOT MEANT TO BE USED IN PRODUCTION.

set -euo pipefail

cd -P -- "$(dirname -- "$0")/.."

if [[ $# -ne 1 ]]; then
  >&2 echo "USAGE: $(basename "$0") PHOTOR_DIR"
  >&2 echo "exiting."
  exit 1
fi

export PHOTOR_DIR="$1"

_build/prod/rel/photor_app/bin/server
