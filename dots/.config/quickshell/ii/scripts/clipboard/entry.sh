#!/usr/bin/env bash
set -euo pipefail

action="${1:?clipboard action required}"
backend="${2:?clipboard command required}"
entry="${3:?clipboard entry required}"
id="${entry%%$'\t'*}"
[[ "$id" =~ ^[0-9]+$ ]] || { echo 'Invalid clipboard entry ID.' >&2; exit 2; }

decode() {
    if [[ "$backend" == *cliphist* ]]; then
        printf '%s\n' "$entry" | "$backend" decode
    else
        "$backend" decode "$id"
    fi
}

case "$action" in
    copy|preview)
        # Decode first so that an expired entry cannot replace the current clipboard.
        temp="$(mktemp --tmpdir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}" redshift-clipboard.XXXXXX)"
        trap 'rm -f -- "$temp"' EXIT
        decode > "$temp"
        if [[ "$action" == preview ]]; then
            printf '%s\n' "$temp"
            trap - EXIT
        else
            wl-copy < "$temp"
        fi
        ;;
    delete)
        printf '%s\n' "$entry" | "$backend" delete
        ;;
    *)
        echo "Unknown clipboard action: $action" >&2
        exit 2
        ;;
esac
