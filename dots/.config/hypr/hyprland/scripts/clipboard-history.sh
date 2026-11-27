#!/usr/bin/env bash
set -o pipefail

config="${1:-ii}"
# Open the native panel if it can accept the request. Fallback is a separate path.
if timeout -k 1 2 qs -c "$config" ipc call clipboardHistory toggle; then
    exit 0
fi

for command in cliphist fuzzel wl-copy; do
    if ! command -v "$command" >/dev/null; then
        printf 'Clipboard history fallback requires %s.\n' "$command" >&2
        exit 1
    fi
done

if [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
    exec 9>"$XDG_RUNTIME_DIR/redshift-clipboard-menu.lock" || exit 1
    flock -n 9 || exit 0
fi

history="$(cliphist list 2>&1)" || {
    if [[ "$history" == 'opening db: please store something first' ]]; then
        history=
    else
        printf '%s\n' "$history" >&2
        exit 1
    fi
}
[[ -n "$history" ]] || {
    if command -v notify-send >/dev/null; then
        notify-send -a 'Redshift OS' 'Clipboard history is empty'
    fi
    exit 0
}

entry="$(printf '%s\n' "$history" | fuzzel --match-mode fzf --dmenu 9>&-)" || exit 0
[[ -n "$entry" ]] || exit 0
entry_script="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/$config/scripts/clipboard/entry.sh"
if [[ -x "$entry_script" ]]; then
    exec "$entry_script" copy cliphist "$entry" 9>&-
fi

# Keep working if Hyprland is installed without the end-4 configuration.
temp="$(mktemp --tmpdir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}" redshift-clipboard.XXXXXX)" || exit 1
trap 'rm -f -- "$temp"' EXIT
printf '%s\n' "$entry" | cliphist decode > "$temp" && wl-copy < "$temp" 9>&-
