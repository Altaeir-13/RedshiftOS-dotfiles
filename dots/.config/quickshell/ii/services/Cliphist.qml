pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property list<string> entries: []
    property bool refreshPending: false
    property bool listUnavailable: false
    readonly property bool loading: readProc.running
    readonly property string emptyMessage: listUnavailable ? Translation.tr("Could not read clipboard history")
        : entries.length > 0 ? Translation.tr("No matching clipboard entries")
        : Translation.tr("Clipboard history is empty")
    readonly property string entryScript: Quickshell.shellPath("scripts/clipboard/entry.sh")
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))
    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }
        if (root.sloppySearch) {
            const results = entries.slice(0, 100).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function refresh() {
        if (readProc.running) {
            refreshPending = true;
            return;
        }
        readProc.buffer = [];
        readProc.running = true;
    }

    function entryCommand(action, entry) {
        if (!/^\d+\t/.test(entry))
            return [];
        return [entryScript, action, root.cliphistBinary, entry];
    }

    function copy(entry) {
        const command = entryCommand("copy", entry);
        if (command.length)
            Quickshell.execDetached(command);
    }

    function paste(entry) {
        const command = entryCommand("copy", entry);
        if (command.length)
            Quickshell.execDetached(["bash", "-c", '"$@" && ' + (root.cliphistBinary.includes("cliphist") ? "wl-paste" : root.pressPasteCommand), "cliphist-paste", ...command]);
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => entryCommand("copy", entry))
            .filter(command => command.length)
            .map(command => command.map(arg => `'${StringUtils.shellSingleQuoteEscape(arg)}'`).join(" ")
                + ` && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: deleteProc
        function deleteEntry(entry) {
            const command = root.entryCommand("delete", entry);
            if (!running && command.length)
                exec(command);
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || exitStatus !== 0)
                console.warn("[Cliphist] Delete failed with code", exitCode, "and status", exitStatus);
            root.refresh();
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    Process {
        id: wipeProc
        command: [root.cliphistBinary, "wipe"]
        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    Process {
        id: readProc
        property list<string> buffer: []

        command: ["sh", "-c", 'exec "$1" list', "cliphist-list", root.cliphistBinary]

        stdout: SplitParser {
            onRead: (line) => {
                if (/^\d+\t/.test(line))
                    readProc.buffer.push(line);
            }
        }

        stderr: StdioCollector {
            id: listErrors
        }

        onExited: (exitCode, exitStatus) => {
            const errorText = listErrors.text.trim();
            const firstRun = exitCode === 1 && errorText === "opening db: please store something first";
            root.listUnavailable = exitStatus !== 0 || (exitCode !== 0 && !firstRun);
            root.entries = root.listUnavailable ? [] : readProc.buffer;
            if (root.listUnavailable)
                console.warn("[Cliphist] Could not list entries:", exitCode, exitStatus, errorText);
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }
}
