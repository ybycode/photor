#!/usr/bin/env bash

set -euo pipefail

export MIX_ENV=prod

mix deps.get
mix do assets.setup, assets.build, assets.deploy
mix release --overwrite
