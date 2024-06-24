#!/usr/bin/with-contenv bashio

set -euo pipefail
[[ -v DEBUG ]] && set -x

CONFIG_PATH=/data/options.json
DOMAIN="$(jq -r '.domain // empty' "${CONFIG_PATH}")"
NAME="$(jq -r '.name // empty' "${CONFIG_PATH}")"
DIGITALOCEAN_TOKEN="$(jq -r '.digitalocean_token // empty' "${CONFIG_PATH}")"
SLEEP_INTERVAL="$(jq -r '.sleep_interval // empty' "${CONFIG_PATH}")"
export DOMAIN NAME DIGITALOCEAN_TOKEN SLEEP_INTERVAL

/ddns.bash
