pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How each module behaves and is laid out. Settings a person rather than
// the repo should decide are read from the user's config.json over the
// defaults; so far only the weather's are, and the rest are edited in
// the files beside this one.
Singleton {
    id: root

    readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/morph-shell/config.json`
    property var user: ({})

    readonly property BarConfig bar: BarConfig {}
    readonly property DockConfig dock: DockConfig {}
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
        path: root.configPath

        watchChanges: true
        onFileChanged: reload()

        onLoaded: {
            try {
                root.user = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`config: ${root.configPath} is not valid JSON (${e}); keeping the settings from before.`);
            }
        }

        printErrors: false
        onLoadFailed: root.user = {}
    }
}
