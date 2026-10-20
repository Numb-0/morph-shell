pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services.launcher
import qs.services.session

// The theme window: every chromix theme as a tile, a large preview of
// the one being looked at, and a light/dark choice, on a card over a dim
// the way the polkit dialog is.
//
// Nothing switches until Apply. Pointing at a tile, or stepping onto it
// with the arrows, only previews it: the hero shows its wallpaper with a
// small shell drawn in its colours, and the window itself fades into its
// palette. The selection is a drop of the theme's primary that flows
// from tile to tile rather than jumping.
//
// Apply floods the new theme out from the tile. Every screen is frozen
// as it was, chromix relinks and reloads everything behind the still,
// and once it is done the still is wiped away in a circle growing from
// the tile, the re-themed desktop underneath. Apps reloading one by one
// never show.
//
// Opened from the bar's palette glyph, the launcher's `:theme` or a
// bind. The arrows move, Enter applies, Escape backs out.
Scope {
    id: root

    // Loaded, and drawn. Closing fades it out before unloading it, so the
    // two part for the length of the fade.
    property bool active: false
    property bool shown: false

    // The screen the card and the keyboard go to, chosen once on opening.
    property string keyScreen: ""

    // What Apply would switch to: the selected tile and the chosen mode.
    property string picked: ""
    property string pickedMode: "dark"

    // The tile under the pointer, which the preview follows over the
    // selection while it is there.
    property string hovered: ""

    readonly property string previewed: hovered !== "" ? hovered : picked

    readonly property bool changed: picked !== Themes.theme || pickedMode !== Themes.mode

    // The wallpaper and colours of every theme in the chosen mode, read
    // once here so the tiles, the preview and the palette share them.
    readonly property var infos: themeInfos.instances

    function infoFor(name: string): var {
        return infos.find(i => i.name === name) ?? null;
    }

    // chromix's names are file names: "mystic_castle" reads as "Mystic
    // castle".
    function displayName(name: string): string {
        const spaced = name.replace(/[_-]+/g, " ");
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    readonly property var previewInfo: infoFor(previewed)

    readonly property ThemePalette tones: ThemePalette {
        roles: root.previewInfo?.colors ?? ({})
    }

    // How long the circle takes to cross the farthest screen, how long
    // the apps are given to repaint after chromix is done, and how long
    // a switch may take before the still is wiped away regardless.
    readonly property int revealDuration: 1000
    readonly property int settleDelay: 450
    readonly property int switchTimeout: 12000

    // The flood, in its stages: the card going (flooding), every screen
    // held still (frozen), chromix asked (started), and the circle
    // growing (revealing).
    property bool flooding: false
    property bool frozen: false
    property bool started: false
    property bool revealing: false

    // Where the circle grows from, in global coordinates, and how far it
    // has to go to clear every screen.
    property point origin: Qt.point(0, 0)
    property real reach: 0

    // 0 to 1 across the reveal.
    property real reveal: 0

    property int captures: 0

    function open(): void {
        if (shown || flooding || !Themes.available)
            return;
        unload.stop();
        keyScreen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        picked = Themes.theme;
        pickedMode = Themes.mode;
        hovered = "";
        active = true;
        shown = true;
    }

    function close(): void {
        if (!shown || flooding)
            return;
        shown = false;
        unload.restart();
    }

    function toggle(): void {
        if (shown)
            close();
        else
            open();
    }

    // Applies what is picked, flooding it out from `from`, a point in
    // global coordinates. With nothing to change it only closes.
    function apply(from: point): void {
        if (!shown || flooding)
            return;
        if (!changed) {
            close();
            return;
        }

        origin = from;
        let far = 0;
        for (const s of Quickshell.screens) {
            for (const [cx, cy] of [[s.x, s.y], [s.x + s.width, s.y], [s.x, s.y + s.height], [s.x + s.width, s.y + s.height]])
                far = Math.max(far, Math.hypot(cx - from.x, cy - from.y));
        }
        // A little past the corner, so the wavefront's glow clears it too.
        reach = far + 48;

        flooding = true;
        shown = false;
        unload.stop();
        freeze.restart();
    }

    // Each screen's still, as it comes in. chromix is only asked once
    // every screen is held, so none of them catches an app mid-reload.
    function captured(): void {
        captures++;
        if (captures >= Quickshell.screens.length)
            start();
    }

    function start(): void {
        if (started)
            return;
        started = true;
        captureTimeout.stop();
        safety.restart();
        Themes.set(picked, pickedMode !== Themes.mode ? pickedMode : "");
    }

    function beginReveal(): void {
        if (revealing)
            return;
        settle.stop();
        safety.stop();
        revealing = true;
        grow.restart();
    }

    function finish(): void {
        flooding = false;
        frozen = false;
        started = false;
        revealing = false;
        reveal = 0;
        captures = 0;
        active = false;
    }

    // One per theme, reloading as the mode is flipped so the tiles show
    // each theme in the mode Apply would bring.
    Variants {
        id: themeInfos

        model: Themes.themes

        Scope {
            id: info

            required property var modelData

            readonly property string name: modelData.name
            readonly property string dir: Themes.dirFor(name, root.pickedMode)

            property string wallpaper: ""
            property var colors: ({})

            // What the theme was rendered from. chromix writes it for
            // every theme, beside the shell's own colours out of it.
            FileView {
                path: info.dir ? `${info.dir}/chromix.json` : ""
                printErrors: false

                onLoaded: {
                    try {
                        info.wallpaper = JSON.parse(text()).source?.image ?? "";
                    } catch (e) {
                        info.wallpaper = "";
                    }
                }
            }

            FileView {
                path: info.dir ? `${info.dir}/morph-shell/colors.json` : ""
                printErrors: false

                onLoaded: {
                    try {
                        const roles = {};
                        const parsed = JSON.parse(text());
                        for (const key in parsed)
                            roles[key.replace(/_(\w)/g, (_, c) => c.toUpperCase())] = parsed[key];
                        info.colors = roles;
                    } catch (e) {
                        info.colors = {};
                    }
                }
            }
        }
    }

    // Long enough for the card and the dim to have faded, so the stills
    // are of the desktop and not of the window on its way out.
    Timer {
        id: freeze

        interval: Appearance.anim.durations.slowEffects + 50
        onTriggered: {
            root.captures = 0;
            root.frozen = true;
            captureTimeout.restart();
        }
    }

    // A screen whose still never arrives does not hold up the rest.
    Timer {
        id: captureTimeout

        interval: 600
        onTriggered: root.start()
    }

    // Gives the apps chromix reloaded a moment to repaint, and the shell
    // its own palette fade, before they are shown.
    Timer {
        id: settle

        interval: root.settleDelay
        onTriggered: root.beginReveal()
    }

    Timer {
        id: safety

        interval: root.switchTimeout
        onTriggered: root.beginReveal()
    }

    Connections {
        target: Themes

        function onFinished(): void {
            if (root.started && !root.revealing)
                settle.restart();
        }
    }

    // On M3's emphasized curve: the wave gathers out of the tile, sweeps
    // across, and eases off as it clears the farthest corner. A curve
    // that decelerates from the start spends nearly all of it past the
    // screen's edge.
    NumberAnimation {
        id: grow

        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: root.revealDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.anim.emphasized

        onFinished: root.finish()
    }

    // Long enough for the slowest fade on the way out to play.
    Timer {
        id: unload

        interval: Appearance.anim.durations.slowEffects + 50
        onTriggered: root.active = false
    }

    // From the launcher's commands and the bar's palette glyph.
    Connections {
        target: Commands

        function onThemesRequested(): void {
            root.open();
        }
    }

    //   morph-shell ipc call themes toggle
    IpcHandler {
        target: "themes"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }

    LazyLoader {
        active: root.active

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property ShellScreen modelData

                readonly property bool main: modelData.name === root.keyScreen

                screen: modelData
                color: "transparent"

                // Over everything, the bar and notifications included,
                // and reserving nothing. Only the card's screen takes the
                // keyboard, and none does while the flood plays.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-themes"
                WlrLayershell.keyboardFocus: main && root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                // Tinted by the theme being looked at, as the card is.
                Rectangle {
                    id: scrim

                    anchors.fill: parent

                    color: {
                        const c = root.tones.m3scrim;
                        return Qt.rgba(c.r, c.g, c.b, 0.45);
                    }

                    opacity: 0
                    Component.onCompleted: opacity = Qt.binding(() => root.shown ? 1 : 0)

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                // A click on the dim closes, as an M3 dialog's does. It
                // also keeps the desktop out of reach while the flood
                // plays, since nothing under a still is where it looks.
                MouseArea {
                    anchors.fill: parent

                    onClicked: root.close()
                }

                Loader {
                    anchors.centerIn: parent

                    active: win.main

                    sourceComponent: ThemeCard {
                        picker: root
                        screen: win.modelData
                    }
                }

                Flood {
                    anchors.fill: parent

                    picker: root
                    screen: win.modelData
                }
            }
        }
    }
}
