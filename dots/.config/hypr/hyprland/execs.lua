-- put former exec-once commands inside the func and former exec commands outside
hl.on("hyprland.start", function ()

    -- Bar, wallpaper
    hl.exec_cmd("$HOME/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")
    -- redshift-ui-watchdog.service starts with the current Wayland session environment.
    hl.exec_cmd([["${XDG_BIN_HOME:-$HOME/.local/bin}/redshift-ui-recover" --session-start]])

    -- Core components (authentication, lock screen, notification daemon)
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP") -- Some fix idk

    -- Audio
    hl.exec_cmd("easyeffects --hide-window --service-mode")

    -- Clipboard: history
    for _, kind in ipairs({ "text", "image" }) do
        hl.exec_cmd("wl-paste --type " .. kind .. [[ --watch sh -c '
            cliphist store || exit
            if timeout -k 1 2 qs -c "$qsConfig" ipc show >/dev/null 2>&1; then
                timeout -k 1 2 qs -c "$qsConfig" ipc call cliphistService update
            fi
        ']])
    end

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)
