#!/usr/bin/env bash
# This script runs a loop that continuously updates a DigitalOcean DNS record to
# reflect this computer's current IP address. It uses an IP address mirror
# service to discover the computer's current IP address and updates the DNS
# record if the address is different.
#
# Args: None
# Env:
#   Required:
#     DOMAIN:            The top level domain name (example.com)
#     NAME:              The subdomain name (home)
#     DIGIALOCEAN_TOKEN: A DigitalOcean personal access token with permission to
#                        read, create, and update domain entries.
#   Optional:
#     DIGITALOCAEN_TOKEN_FILE: If set, DIGITALOCEAN_TOKEN will be read from this
#                              file.
#     SLEEP_INTERVAL:          The number of seconds to wait between updates.
#                              Defaults to 60.

set -euo pipefail
[[ -v DEBUG ]] && set -x

debug() {
    echo "$@" 1>&2
}

die() {
    debug "$@"
    exit 1
}

(( $# == 0 )) || die "Got $# arguments, want 0"

[[ -n "${DOMAIN:-}" ]] || die "DOMAIN not set"
[[ -n "${NAME:-}" ]] || die "NAME not set"

if [[ -f "${DIGITALOCEAN_TOKEN_FILE:-}" ]]; then
    DIGITALOCEAN_TOKEN="$(cat "${DIGITALOCEAN_TOKEN_FILE}")"
fi
[[ -n "${DIGITALOCEAN_TOKEN:-}" ]] || die "DIGITALOCEAN_TOKEN not set"

API_HOST="${API_HOST:-https://api.digitalocean.com/v2}"
SLEEP_INTERVAL="${SLEEP_INTERVAL:-60}"
IP_SERVICES=(
    v4.ident.me
    ifconfig.co
    ifconfig.me
    api.ipify.org
)
resolve_ip() {
    for service in "${IP_SERVICES[@]}"; do
        debug "Trying ${service}"
        if curl -s "${service}"; then
            return
        fi
    done
    return 1
}

API="${API_HOST}/domains/${DOMAIN}/records"
api_curl() {
    curl -s --fail-with-body \
        -H "Authorization: Bearer ${DIGITALOCEAN_TOKEN}" \
        "$@"
}

run() {
    local addr
    if ! addr="$(resolve_ip)"; then
        debug "Unable to resolve current IP."
        return 1
    fi

    if [[ -v old_addr && "${old_addr}" == "${addr}" ]]; then
        debug "IP address has not changed."
        return
    fi
    old_addr="${addr}"

    local record
    if ! record="$(api_curl -X GET "${API}?type=A&name=${NAME}.${DOMAIN}" \
        | jq ".domain_records[0] // empty")"; then

        debug "Unable to discover current DNS record."
        return 1
    fi

    if [[ -n "${record}" ]]; then
        # Update existing record, if necessary.
        local record_addr
        if ! record_addr="$(jq -r '.data // empty' <<< "${record}")"; then
            debug "Couldn't extract data from DNS record."
            return 1
        fi
        if [[ "${record_addr}" == "${addr}" ]]; then
            debug "DNS record has correct address."
            return
        fi

        local record_id
        if ! record_id="$(jq -r '.id // empty' <<< "${record}")"; then
            debug "Couldn't extract id from DNS record."
            return 1
        fi
        if [[ -z "${record_id}" ]]; then
            debug "DNS record ID appears to be empty."
            return 1
        fi

        local req
        printf -v req '{"data": "%s", "ttl": %d}' "${addr}" "${SLEEP_INTERVAL}"
        if ! api_curl -X PATCH "${API}/${record_id}" -d "${req}"; then
            debug "Unable to update existing DNS record."
            return 1
        fi
        echo # Add a newline for the curl output.
    else
        # Create new record.
        local req
        printf -v req '{"type": "A", "name": "%s", "data": "%s", "ttl": %d}' "${NAME}" "${addr}" "${SLEEP_INTERVAL}"
        if ! api_curl -X POST "${API}" -d "${req}"; then
            debug "Unable to create DNS record."
            return 1
        fi
        echo # Add a newline for the curl output.
    fi
}

while true; do
    if ! run; then
       debug "Attempt failed, trying again in ${SLEEP_INTERVAL} seconds."
    fi
    sleep "${SLEEP_INTERVAL}"
done
