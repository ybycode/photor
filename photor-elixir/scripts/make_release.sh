#!/usr/bin/env bash

set -euo pipefail

export MIX_ENV=prod

mix assets.build
mix assets.deploy
mix release --overwrite
