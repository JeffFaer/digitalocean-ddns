#!/usr/bin/env bash

set -euo pipefail
[[ -v DEBUG ]] && set -x

dir="$(dirname "${BASH_SOURCE[0]}")/.."
docker run \
    --rm -it --name builder --privileged \
    -v "${dir}":/data \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    ghcr.io/home-assistant/amd64-builder \
    -t /data --all --test -i "digitalocean-ddns-{arch}" -d local
