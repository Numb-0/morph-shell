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

// The theme switcher, as liquid. Every chromix theme is a drop of its
// primary in a row strung together like the workspaces, and the drop
// being looked at swells and reaches up into a bubble holding a large
// preview of it: its wallpaper with a small shell drawn in its colours.
// The whole switcher fades into the palette of whichever drop is up.
//
// Pointing at a drop, or stepping onto it with the arrows, only
// previews it. A click on it, or Enter, applies it: the other drops and
// the bubble draw into it, and it swells until it floods every screen.
// chromix relinks and reloads everything under the flood, so apps
// reloading one by one never show, and once it is done the flood drains
// back into the drop and it shrinks away.
//
// Opened from the bar's palette glyph, the launcher's `:theme` or a
// bind. Left and right move, Tab flips light and dark, Enter applies,
// Escape backs out.
Scope {
    id: root

    // Loaded, and drawn. Closing plays the drops out before unloading
    // them, so the two part for the length of that.
    property bool active: false
    property bool shown: false

    // The screen the switcher and the keyboard go to, chosen once on
    // opening.
    property string keyScreen: ""

    // The drop the keyboard is on, and the mode Apply would bring.
    property string picked: ""
    property string pickedMode: "dark"

    // The drop under the pointer, which the preview follows over the
    // keyboard's while it is there.
    property string hovered: ""

    readonly property string previewed: hovered !== "" ? hovered : picked

    // The wallpaper and colours of every theme in the chosen mode, read
    // once here so the drops, the preview and the palette share them.
    readonly property var infos: themeInfos.instances

    function infoFor(name: string): var {
        return infos.find(i => i.name === name) ?? null;
    }

    readonly property var previewInfo: infoFor(previewed)

    readonly property ThemePalette tones: ThemePalette {
        roles: root.previewInfo?.colors ?? ({})
    }

    // chromix's names are file names: "mystic_castle" reads as "Mystic
    // castle".
    function displayName(name: string): string {
        const spaced = name.replace(/[_-]+/g, " ");
        return spaced.charAt(0).toUpperCase() + spaced.slice(1);
    }

    // How long the drops take to gather into the chosen one, the flood
    // to cover the farthest screen and to drain back, how long the apps
    // are given to repaint once chromix is done, and how long a switch
    // may take before the flood drains regardless.
    readonly property int gatherDuration: 420
    readonly property int floodDuration: 750
    readonly property int drainDuration: 750
    readonly property int settleDelay: 450
    readonly property int switchTimeout: 12000

    // The chosen drop at its fullest, which the flood grows out of and
    // drains back into.
    readonly property real dropRadius: 36

    // A switch on its way, in its stages: the drops gathering into the
    // chosen one (committing), the flood over every screen (flooding),
    // every screen covered and chromix asked (covered), and the flood
    // going back (draining).
    property bool committing: false
    property bool flooding: false
    property bool covered: false
    property bool draining: false

    // Where the flood grows from, in global coordinates, and how far it
    // has to go to cover every screen.
    property point origin: Qt.point(0, 0)
    property real reach: 0

    // 0 to 1, the flood's reach; 0 to 1, its colour from the theme's
    // primary into its container; and the last drop's size as it goes.
    property real flood: 0
    property real tint: 0
    property real pop: 1

    function open(): void {
        if (shown || committing || !Themes.available)
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
        if (!shown || committing)
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

    // Applies a theme in the chosen mode, flooding it out from `from`,
    // the drop's centre in global coordinates. With nothing to change it
    // only closes.
    function apply(name: string, from: point): void {
        if (!shown || committing)
            return;
        if (name === Themes.theme && pickedMode === Themes.mode) {
            close();
            return;
        }

        picked = name;
        hovered = "";
        origin = from;
        let far = 0;
        for (const s of Quickshell.screens) {
            for (const [cx, cy] of [[s.x, s.y], [s.x + s.width, s.y], [s.x, s.y + s.height], [s.x + s.width, s.y + s.height]])
                far = Math.max(far, Math.hypot(cx - from.x, cy - from.y));
        }
        reach = far;

        committing = true;
        shown = false;
        unload.stop();
        gather.restart();
    }

    function finish(): void {
        committing = false;
        flooding = false;
        covered = false;
        draining = false;
        flood = 0;
        tint = 0;
        pop = 1;
        active = false;
    }

    // One per theme, reloading as the mode is flipped so the drops and
    // the preview show each theme in the mode Apply would bring.
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

    // The drops drawing into the chosen one, before it floods.
    Timer {
        id: gather

        interval: root.gatherDuration
        onTriggered: {
            root.flooding = true;
            spread.restart();
        }
    }

    // Out of the drop and over every screen, its colour running from the
    // theme's primary into its surface as it goes. Only once it covers
    // everything is chromix asked.
    ParallelAnimation {
        id: spread

        NumberAnimation {
            target: root
            property: "flood"
            from: 0
            to: 1
            duration: root.floodDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.emphasized
        }

        NumberAnimation {
            target: root
            property: "tint"
            from: 0
            to: 1
            duration: root.floodDuration * 0.6
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.standard
        }

        onFinished: {
            root.covered = true;
            safety.restart();
            Themes.set(root.picked, root.pickedMode !== Themes.mode ? root.pickedMode : "");
        }
    }

    // Gives the apps chromix reloaded a moment to repaint, and the shell
    // its own palette fade, before the flood goes.
    Timer {
        id: settle

        interval: root.settleDelay
        onTriggered: root.drain()
    }

    Timer {
        id: safety

        interval: root.switchTimeout
        onTriggered: root.drain()
    }

    function drain(): void {
        if (draining)
            return;
        settle.stop();
        safety.stop();
        draining = true;
        recede.restart();
    }

    Connections {
        target: Themes

        function onFinished(): void {
            if (root.covered && !root.draining)
                settle.restart();
        }
    }

    // Back into the drop it came from, the edges of every screen showing
    // first, then turning primary again as it narrows. It speeds up as it
    // goes, M3's emphasized accelerate, and runs straight on into the
    // drop shrinking away, so there is no tail of it creeping in nor a
    // pause before the pop: a curve that eases out lingers for half a
    // second on a drop that barely moves.
    SequentialAnimation {
        id: recede

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "flood"
                to: 0
                duration: root.drainDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.3, 0, 0.8, 0.15, 1, 1]
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: root.drainDuration * 0.55
                }
                NumberAnimation {
                    target: root
                    property: "tint"
                    to: 0
                    duration: root.drainDuration * 0.45
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.standard
                }
            }
        }

        // Picks up the speed the drain arrived with and settles to
        // nothing, M3's emphasized decelerate.
        NumberAnimation {
            target: root
            property: "pop"
            to: 0
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1]
        }

        onFinished: root.finish()
    }

    // Long enough for the drops to play out on the way out.
    Timer {
        id: unload

        interval: Appearance.anim.durations.slowEffects + 100
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
                // and reserving nothing. Only the switcher's screen takes
                // the keyboard, and none does while a switch plays.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "morph-shell-themes"
                WlrLayershell.keyboardFocus: main && root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                // Tinted by the theme being looked at. Held through the
                // gather, so the desktop does not brighten between the
                // switcher going and the flood arriving.
                Rectangle {
                    id: scrim

                    anchors.fill: parent

                    color: {
                        const c = root.tones.m3scrim;
                        return Qt.rgba(c.r, c.g, c.b, 0.5);
                    }

                    opacity: 0
                    Component.onCompleted: opacity = Qt.binding(() => root.shown || (root.committing && !root.covered) ? 1 : 0)

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                // A click on the dim closes. It also keeps the desktop
                // out of reach while a switch plays.
                MouseArea {
                    anchors.fill: parent

                    onClicked: root.close()
                }

                Loader {
                    anchors.centerIn: parent

                    active: win.main

                    sourceComponent: Droplets {
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
