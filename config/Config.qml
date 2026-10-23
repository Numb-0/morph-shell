pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How each module behaves and is laid out. Settings a person rather than
// the repo should decide are read from the user's config.json over the
// defaults; so far the weather's and the dock's pins are, and the rest
// are edited in the files beside this one. The pins are also written
// back, when they are changed from the shell.
Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/morph-shell/config.json`
    property var user: ({})

    // Whether the file as it stands was read, or is missing. One that
    // does not parse is never written over: it is half an edit, and
    // the shell's change would throw away the rest of it.
    property bool writable: true

    // Changes one setting in the file, keeping everything else in it as
    // it was, and takes it at once rather than waiting to read it back.
    function set(section: string, key: string, value: var): void {
        if (!writable) {
            console.warn(`config: not saving ${section}.${key}, as ${root.configPath} is not valid JSON.`);
            return;
        }

        const next = Object.assign({}, root.user);
        next[section] = Object.assign({}, next[section] ?? {}, {
            [key]: value
        });

        root.user = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
    }

    readonly property BarConfig bar: BarConfig {}
    readonly property DockConfig dock: DockConfig {
        user: root.user.dock ?? {}
    }
    readonly property OverviewConfig overview: OverviewConfig {}
    readonly property OsdConfig osd: OsdConfig {
        dock: root.dock
    }
    readonly property NotifsConfig notifs: NotifsConfig {
        bar: root.bar
    }
    readonly property IdleConfig idle: IdleConfig {}
    readonly property WeatherConfig weather: WeatherConfig {
        user: root.user.weather ?? {}
    }

    // Followed as it is edited, so a change shows without a restart. A
    // file that does not parse is left out rather than half applied.
    FileView {
        id: file

        path: root.configPath

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                root.user = JSON.parse(text()) ?? {};
                root.writable = true;
            } catch (e) {
                root.writable = false;
                console.warn(`config: ${root.configPath} is not valid JSON (${e}); keeping the settings from before.`);
            }
        }

        printErrors: false
        onLoadFailed: {
            root.user = {};
            root.writable = true;
        }
    }
}
