pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

Singleton {
    id: root

    readonly property var entries: Config.bar.entries.values
    readonly property var statusIcons: Config.bar.statusIcons.values

    function isEntryEnabled(id: string, defaultVal): bool {
        const fallback = defaultVal !== undefined ? defaultVal : true;
        const item = root.entries.find(e => e.id === id);
        return item ? item.enabled : fallback;
    }

    function setEntryEnabled(id: string, enabled: bool) {
        const list = GlobalConfig.bar.entries;
        for (let i = 0; i < list.count; i++) {
            const item = list.at(i);
            if (item.id === id) {
                item.enabled = enabled;
                return;
            }
        }
        list.insert({
            id: id,
            enabled: enabled
        });
    }

    function isStatusIconEnabled(id: string, defaultVal): bool {
        const fallback = defaultVal !== undefined ? defaultVal : true;
        const item = root.statusIcons.find(e => e.id === id);
        return item ? item.enabled : fallback;
    }

    function setStatusIconEnabled(id: string, enabled: bool) {
        const list = GlobalConfig.bar.statusIcons;
        for (let i = 0; i < list.count; i++) {
            const item = list.at(i);
            if (item.id === id) {
                item.enabled = enabled;
                return;
            }
        }
        list.insert({
            id: id,
            enabled: enabled
        });
    }
}
