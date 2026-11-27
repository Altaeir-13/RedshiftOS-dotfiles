#!/usr/bin/env bash

# Keep the stock preference order, including the names used by Arch packages.
for browser in google-chrome-stable google-chrome zen-browser zen firefox brave brave-browser chromium microsoft-edge-stable opera librewolf; do
    if command -v "$browser" >/dev/null; then
        if "$browser"; then
            exit 0
        fi
        printf 'Redshift OS: não foi possível iniciar %s.\n' "$browser" >&2
    fi
done

# Browsers installed as Flatpaks or by other means can be registered as desktop apps.
if command -v gtk-launch >/dev/null && command -v xdg-mime >/dev/null; then
    desktop="$(xdg-mime query default x-scheme-handler/https)" || desktop=
    if [[ "$desktop" == *.desktop ]] && gtk-launch -- "$desktop"; then
        exit 0
    fi
fi

message='Nenhum navegador pôde ser aberto. Instale um navegador, configure o aplicativo padrão para HTTPS ou ajuste browser em hypr/custom/variables.lua.'
printf 'Redshift OS: %s\n' "$message" >&2
if command -v notify-send >/dev/null; then
    notify-send -a 'Redshift OS' 'Navegador indisponível' "$message"
fi
exit 1
