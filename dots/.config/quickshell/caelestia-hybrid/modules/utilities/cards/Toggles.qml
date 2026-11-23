pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.bar.popouts as BarPopouts

StyledRect {
    id: root

    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts

    readonly property var quickToggles: {
        const seenIds = new Set();

        const items =
            Config.utilities.quickToggles.values.filter(item => {
                if (!item.enabled)
                    return false;

                if (seenIds.has(item.id))
                    return false;

                if (item.id === "vpn"
                        && GlobalConfig.utilities.vpn
                            .selectedProvider.length === 0)
                    return false;

                seenIds.add(item.id);
                return true;
            });

        // Toggle adicional do híbrido: ativo por padrão se não configurado explicitamente.
        const configuredNightLight = Config.utilities.quickToggles.values.find(t => t.id === "nightLight");
        if (configuredNightLight === undefined && !seenIds.has("nightLight")) {
            items.push({
                id: "nightLight",
                enabled: true
            });
        }

        return items;
    }

    property bool nightLightEnabled: false

    readonly property int splitIndex: Math.ceil(quickToggles.length / 2)
    readonly property bool needExtraRow: quickToggles.length > 6

    implicitHeight: layout.implicitHeight + Tokens.padding.extraLargeIncreased

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    Process {
        running: true

        command: [
            "bash",
            "-lc",
            "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/nightlight\" 2>/dev/null || echo off"
        ]

        stdout: StdioCollector {
            onStreamFinished:
                root.nightLightEnabled =
                    text.trim() === "on"
        }
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: Tr.tr("Quick toggles")
            font: Tokens.font.body.medium
        }

        QuickToggleRow {
            model: root.needExtraRow ? root.quickToggles.slice(0, root.splitIndex) : root.quickToggles
        }

        QuickToggleRow {
            visible: root.needExtraRow
            model: root.needExtraRow ? root.quickToggles.slice(root.splitIndex) : []
        }
    }

    component QuickToggleRow: ButtonRow {
        property alias model: repeater.model

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        Repeater {
            id: repeater

            delegate: DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "wifi"
                    delegate: Toggle {
                        icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
                        checked: Nmcli.wifiEnabled
                        onClicked: Nmcli.toggleWifi()
                    }
                }
                DelegateChoice {
                    roleValue: "bluetooth"
                    delegate: Toggle {
                        icon: (Bluetooth.defaultAdapter?.enabled ?? false) ? "bluetooth" : "bluetooth_disabled"
                        checked: Bluetooth.defaultAdapter?.enabled ?? false // qmllint disable unresolved-type
                        onClicked: {
                            const adapter = Bluetooth.defaultAdapter; // qmllint disable unresolved-type
                            if (adapter)
                                adapter.enabled = !adapter.enabled;
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "mic"
                    delegate: Toggle {
                        icon: Audio.sourceMuted ? "mic_off" : "mic"
                        checked: !Audio.sourceMuted
                        onClicked: {
                            const audio = Audio.source?.audio;
                            if (audio)
                                audio.muted = !audio.muted;
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "settings"
                    delegate: Toggle {
                        icon: "settings"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        isToggle: false
                        onClicked: {
                            root.screenState.utilities = false;
                            WindowFactory.create();
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "gameMode"
                    delegate: Toggle {
                        icon: "sports_esports"
                        checked: GameMode.enabled
                        onClicked: GameMode.enabled = !GameMode.enabled
                    }
                }
                DelegateChoice {
                    roleValue: "dnd"
                    delegate: Toggle {
                        icon: Notifs.dnd ? "notifications_off" : "notifications"
                        checked: Notifs.dnd
                        onClicked: Notifs.dnd = !Notifs.dnd
                    }
                }

                DelegateChoice {
                    roleValue: "nightLight"

                    delegate: Toggle {
                        icon: root.nightLightEnabled ? "nightlight" : "light_mode"

                        checked:
                            root.nightLightEnabled

                        onClicked: {
                            root.nightLightEnabled =
                                !root.nightLightEnabled;

                            if (root.nightLightEnabled) {
                                Quickshell.execDetached([
                                    "bash",
                                    "-lc",
                                    "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/caelestia\"; " +
                                    "hyprctl hyprsunset temperature 4500 " +
                                    "&& printf on > \"${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/nightlight\""
                                ]);
                            } else {
                                Quickshell.execDetached([
                                    "bash",
                                    "-lc",
                                    "mkdir -p \"${XDG_STATE_HOME:-$HOME/.local/state}/caelestia\"; " +
                                    "hyprctl hyprsunset identity " +
                                    "&& printf off > \"${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/nightlight\""
                                ]);
                            }
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "vpn"
                    delegate: Toggle {
                        icon: VPN.status.state === "needs-auth"
                            ? "vpn_lock"
                            : (VPN.connected ? "vpn_key" : "vpn_key_off")
                        checked: VPN.connected && VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
                        enabled: !VPN.connecting && !VPN.disconnecting
                        isToggle: VPN.status.state !== "needs-auth" && VPN.status.state !== "error"
                        inactiveOnColour: Colours.palette.m3onSurfaceVariant
                        onClicked: VPN.toggle()
                    }
                }
            }
        }
    }

    component Toggle: IconButton {
        inactiveColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
        fillWidth: true
        isToggle: true
        isRound: true
        shapeMorph: true
    }
}
