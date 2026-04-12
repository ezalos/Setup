#!/usr/bin/env bash
# ABOUTME: Manages Cloudflare DNS records declaratively from a dns.json config file.
# ABOUTME: Supports sync (idempotent create/update), list, status (dry-run diff), and delete.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${DNS_CONFIG:-$SCRIPT_DIR/dns.json}"
CF_API="https://api.cloudflare.com/client/v4"
CF_TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"

# ── Colors (only when stdout is a tty) ──────────────────────────────
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    RED='\033[0;31m'
    DIM='\033[0;90m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    GREEN='' YELLOW='' RED='' DIM='' BOLD='' RESET=''
fi

# ── Preflight checks ────────────────────────────────────────────────
for cmd in jq curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required but not installed."; exit 1; }
done

if [ -z "$CF_TOKEN" ]; then
    echo "ERROR: CLOUDFLARE_API_TOKEN (or CF_API_TOKEN) must be set."
    exit 1
fi

# ── Helpers ──────────────────────────────────────────────────────────

cf_api() {
    local method="$1" path="$2"
    shift 2
    local response
    response=$(curl -s -X "$method" \
        -H "Authorization: Bearer $CF_TOKEN" \
        -H "Content-Type: application/json" \
        "$@" \
        "${CF_API}${path}")

    local success
    success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        echo "ERROR: API call failed: $method $path" >&2
        echo "$response" | jq -r '.errors[]?.message // .' >&2
        return 1
    fi
    echo "$response"
}

ZONE_ID_CACHE=""
get_zone_id() {
    local zone_name="$1"
    if [ -n "$ZONE_ID_CACHE" ]; then
        echo "$ZONE_ID_CACHE"
        return
    fi
    local resp
    resp=$(cf_api GET "/zones?name=${zone_name}")
    ZONE_ID_CACHE=$(echo "$resp" | jq -r '.result[0].id // empty')
    if [ -z "$ZONE_ID_CACHE" ]; then
        echo "ERROR: Zone '$zone_name' not found. Check your API token permissions." >&2
        exit 1
    fi
    echo "$ZONE_ID_CACHE"
}

fqdn() {
    local name="$1" zone="$2"
    if [ "$name" = "@" ]; then
        echo "$zone"
    elif [[ "$name" == *"$zone" ]]; then
        echo "$name"
    else
        echo "${name}.${zone}"
    fi
}

fetch_all_records() {
    local zone_id="$1"
    local page=1 total_pages=1 all_records="[]"

    while [ "$page" -le "$total_pages" ]; do
        local resp
        resp=$(cf_api GET "/zones/${zone_id}/dns_records?per_page=100&page=${page}")
        total_pages=$(echo "$resp" | jq '.result_info.total_pages')
        all_records=$(echo "$all_records" "$resp" | jq -s '.[0] + (.[1].result)')
        page=$((page + 1))
    done
    echo "$all_records"
}

require_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        echo "Copy dns.example.json to dns.json and edit it."
        exit 1
    fi
}

# ── Commands ─────────────────────────────────────────────────────────

cmd_list() {
    require_config
    local zone_name
    zone_name=$(jq -r '.zone' "$CONFIG_FILE")
    local zone_id
    zone_id=$(get_zone_id "$zone_name")

    echo -e "${BOLD}DNS records for ${zone_name}${RESET}"
    echo ""

    local records
    records=$(fetch_all_records "$zone_id")

    echo "$records" | jq -r '.[] | [.type, .name, .content, "proxied=\(.proxied)", "ttl=\(.ttl)"] | @tsv' \
        | sort -k2 \
        | column -t -s $'\t'
}

cmd_status() {
    require_config
    local zone_name
    zone_name=$(jq -r '.zone' "$CONFIG_FILE")
    local zone_id
    zone_id=$(get_zone_id "$zone_name")

    local actual
    actual=$(fetch_all_records "$zone_id")

    local record_count
    record_count=$(jq '.records | length' "$CONFIG_FILE")

    local creates=0 updates=0 ok=0

    echo -e "${BOLD}Status for ${zone_name} (${record_count} records in config)${RESET}"
    echo ""

    for i in $(seq 0 $((record_count - 1))); do
        local type name content proxied ttl full_name
        type=$(jq -r ".records[$i].type" "$CONFIG_FILE")
        name=$(jq -r ".records[$i].name" "$CONFIG_FILE")
        content=$(jq -r ".records[$i].content" "$CONFIG_FILE")
        proxied=$(jq -r "if .records[$i] | has(\"proxied\") then .records[$i].proxied else true end" "$CONFIG_FILE")
        ttl=$(jq -r ".records[$i].ttl // 1" "$CONFIG_FILE")
        full_name=$(fqdn "$name" "$zone_name")

        local match
        match=$(echo "$actual" | jq -c ".[] | select(.type == \"$type\" and .name == \"$full_name\")")

        if [ -z "$match" ]; then
            echo -e "  ${GREEN}CREATE${RESET}  $type  $full_name → $content"
            creates=$((creates + 1))
        else
            local actual_content actual_proxied actual_ttl
            actual_content=$(echo "$match" | jq -r '.content')
            actual_proxied=$(echo "$match" | jq -r '.proxied')
            actual_ttl=$(echo "$match" | jq -r '.ttl')

            local changed=false
            if [ "$actual_content" != "$content" ]; then changed=true; fi
            if [ "$actual_proxied" != "$proxied" ]; then changed=true; fi
            # Skip TTL diff when both are proxied (Cloudflare forces ttl=1)
            if [ "$proxied" != "true" ] && [ "$actual_ttl" != "$ttl" ]; then changed=true; fi

            if [ "$changed" = "true" ]; then
                echo -e "  ${YELLOW}UPDATE${RESET}  $type  $full_name"
                [ "$actual_content" != "$content" ] && echo "          content: $actual_content → $content"
                [ "$actual_proxied" != "$proxied" ] && echo "          proxied: $actual_proxied → $proxied"
                [ "$proxied" != "true" ] && [ "$actual_ttl" != "$ttl" ] && echo "          ttl: $actual_ttl → $ttl"
                updates=$((updates + 1))
            else
                echo -e "  ${DIM}OK${RESET}      $type  $full_name"
                ok=$((ok + 1))
            fi
        fi
    done

    echo ""
    echo "Summary: $ok up-to-date, $creates to create, $updates to update"
}

cmd_sync() {
    require_config
    local zone_name
    zone_name=$(jq -r '.zone' "$CONFIG_FILE")
    local zone_id
    zone_id=$(get_zone_id "$zone_name")

    local actual
    actual=$(fetch_all_records "$zone_id")

    local record_count
    record_count=$(jq '.records | length' "$CONFIG_FILE")

    local creates=0 updates=0 ok=0 errors=0

    echo -e "${BOLD}Syncing DNS for ${zone_name} (${record_count} records)${RESET}"
    echo ""

    for i in $(seq 0 $((record_count - 1))); do
        local type name content proxied ttl comment full_name
        type=$(jq -r ".records[$i].type" "$CONFIG_FILE")
        name=$(jq -r ".records[$i].name" "$CONFIG_FILE")
        content=$(jq -r ".records[$i].content" "$CONFIG_FILE")
        proxied=$(jq -r "if .records[$i] | has(\"proxied\") then .records[$i].proxied else true end" "$CONFIG_FILE")
        ttl=$(jq -r ".records[$i].ttl // 1" "$CONFIG_FILE")
        comment=$(jq -r ".records[$i].comment // empty" "$CONFIG_FILE")
        full_name=$(fqdn "$name" "$zone_name")

        local match
        match=$(echo "$actual" | jq -c ".[] | select(.type == \"$type\" and .name == \"$full_name\")")

        if [ -z "$match" ]; then
            # Create
            echo -ne "  ${GREEN}CREATE${RESET}  $type  $full_name → $content ... "
            local body
            body=$(jq -n \
                --arg type "$type" \
                --arg name "$full_name" \
                --arg content "$content" \
                --argjson proxied "$proxied" \
                --argjson ttl "$ttl" \
                --arg comment "$comment" \
                '{type: $type, name: $name, content: $content, proxied: $proxied, ttl: $ttl} + (if $comment != "" then {comment: $comment} else {} end)')

            if cf_api POST "/zones/${zone_id}/dns_records" -d "$body" > /dev/null; then
                echo "OK"
                creates=$((creates + 1))
            else
                echo -e "${RED}FAILED${RESET}"
                errors=$((errors + 1))
            fi
        else
            local actual_content actual_proxied actual_ttl record_id
            actual_content=$(echo "$match" | jq -r '.content')
            actual_proxied=$(echo "$match" | jq -r '.proxied')
            actual_ttl=$(echo "$match" | jq -r '.ttl')
            record_id=$(echo "$match" | jq -r '.id')

            local changed=false
            if [ "$actual_content" != "$content" ]; then changed=true; fi
            if [ "$actual_proxied" != "$proxied" ]; then changed=true; fi
            if [ "$proxied" != "true" ] && [ "$actual_ttl" != "$ttl" ]; then changed=true; fi

            if [ "$changed" = "true" ]; then
                # Update
                echo -ne "  ${YELLOW}UPDATE${RESET}  $type  $full_name ... "
                local body
                body=$(jq -n \
                    --arg content "$content" \
                    --argjson proxied "$proxied" \
                    --argjson ttl "$ttl" \
                    --arg comment "$comment" \
                    '{content: $content, proxied: $proxied, ttl: $ttl} + (if $comment != "" then {comment: $comment} else {} end)')

                if cf_api PATCH "/zones/${zone_id}/dns_records/${record_id}" -d "$body" > /dev/null; then
                    echo "OK"
                    updates=$((updates + 1))
                else
                    echo -e "${RED}FAILED${RESET}"
                    errors=$((errors + 1))
                fi
            else
                echo -e "  ${DIM}OK${RESET}      $type  $full_name"
                ok=$((ok + 1))
            fi
        fi
    done

    echo ""
    echo "Summary: $ok unchanged, $creates created, $updates updated, $errors errors"
}

cmd_delete() {
    local del_name="${1:-}" del_type="${2:-}"
    local yes_flag="${3:-}"

    if [ -z "$del_name" ] || [ -z "$del_type" ]; then
        echo "Usage: $0 delete NAME TYPE [--yes]"
        echo "Example: $0 delete test-sub A --yes"
        exit 1
    fi

    require_config
    local zone_name
    zone_name=$(jq -r '.zone' "$CONFIG_FILE")
    local zone_id
    zone_id=$(get_zone_id "$zone_name")
    local full_name
    full_name=$(fqdn "$del_name" "$zone_name")

    local actual
    actual=$(fetch_all_records "$zone_id")

    local match
    match=$(echo "$actual" | jq -c ".[] | select(.type == \"$del_type\" and .name == \"$full_name\")")

    if [ -z "$match" ]; then
        echo "No $del_type record found for $full_name"
        exit 1
    fi

    local record_id record_content
    record_id=$(echo "$match" | jq -r '.id')
    record_content=$(echo "$match" | jq -r '.content')

    echo -e "${RED}DELETE${RESET}  $del_type  $full_name → $record_content  (id: $record_id)"

    if [ "$yes_flag" != "--yes" ]; then
        echo -n "Confirm? [y/N] "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Aborted."
            exit 0
        fi
    fi

    if cf_api DELETE "/zones/${zone_id}/dns_records/${record_id}" > /dev/null; then
        echo "Deleted."
    else
        echo -e "${RED}Delete failed.${RESET}"
        exit 1
    fi
}

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Commands:
  list                  List all DNS records in the zone
  status                Dry-run: show what sync would change
  sync                  Create missing / update changed records
  delete NAME TYPE      Delete a record (e.g. delete test-sub A)
    --yes               Skip confirmation prompt
  help                  Show this help

Environment:
  CLOUDFLARE_API_TOKEN  Cloudflare API token (or CF_API_TOKEN)
  DNS_CONFIG            Path to config file (default: dns.json next to this script)

Config file format (dns.json):
  {
    "zone": "example.com",
    "records": [
      {"type": "A", "name": "app", "content": "1.2.3.4", "proxied": true},
      {"type": "CNAME", "name": "www", "content": "app.example.com", "proxied": true}
    ]
  }
EOF
}

# ── Dispatch ─────────────────────────────────────────────────────────

case "${1:-help}" in
    list)   cmd_list ;;
    status) cmd_status ;;
    sync)   cmd_sync ;;
    delete) shift; cmd_delete "$@" ;;
    help|*) usage ;;
esac
