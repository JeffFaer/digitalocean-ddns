#!/usr/bin/env bash

set -euo pipefail
[[ -v DEBUG ]] && set -x

dir="$(dirname "${BASH_SOURCE[0]}")/.."
docker run --rm -v "${dir}/data:/data" local/digitalocean-ddns-amd64
